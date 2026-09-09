import Combine
@preconcurrency import CoreBluetooth
import Foundation
import PhoneControlCore

@MainActor
// CoreBluetooth is explicitly configured to deliver every delegate callback on .main.
final class BluetoothMouse: NSObject, ObservableObject, @preconcurrency CBPeripheralManagerDelegate
{
  @Published private(set) var status = "蓝牙尚未启动"
  @Published private(set) var connected = false
  @Published private(set) var running = false
  @Published var compactDiscovery = true
  @Published var absoluteMode = true
  private(set) var activeAbsolute = true
  @Published private(set) var discoveryStatus = "服务尚未注册"
  private var advertisingCompact = true
  private var registeredServices = 0
  var onReset: (() -> Void)?
  private var manager: CBPeripheralManager?
  private var target: CBCentral?
  private var targetID: UUID?
  private var report: CBMutableCharacteristic?
  private var services: [CBMutableService] = []
  private var transport = MouseTransport()
  private var absoluteTransport = AbsoluteTransport()
  private var suspended = false

  private func uuid(_ short: String) -> CBUUID {
    CBUUID(string: "0000\(short)-0000-1000-8000-00805F9B34FB")
  }

  func start() {
    guard !running else { return }
    running = true
    activeAbsolute = absoluteMode
    absoluteTransport.reset()
    advertisingCompact = compactDiscovery
    registeredServices = 0
    discoveryStatus = "正在准备服务"
    status = "正在初始化蓝牙…"
    // An explicit user action constructs the manager and requests permission.
    manager = CBPeripheralManager(delegate: self, queue: .main)
  }

  func stop() {
    release()
    onReset?()
    manager?.stopAdvertising()
    manager?.removeAllServices()
    manager?.delegate = nil
    manager = nil
    report = nil
    target = nil
    targetID = nil
    services = []
    connected = false
    running = false
    discoveryStatus = "广播已停止"
    status = "蓝牙已停止"
  }

  func send(buttons: UInt8, x: Double = 0, y: Double = 0, wheel: Double = 0) {
    guard connected, !suspended, !activeAbsolute else { return }
    if !transport.enqueue(buttons: buttons, x: x, y: y, wheel: wheel) {
      status = "输入积压已清空，请重新开启控制"
      onReset?()
    }
    flush()
  }

  func sendAbsolute(buttons: UInt8, position: AbsolutePosition, wheel: Double = 0) {
    guard connected, !suspended, activeAbsolute else { return }
    if !absoluteTransport.enqueue(buttons: buttons, position: position, wheel: wheel) {
      status = "输入积压已清空，请重新开启控制"
      onReset?()
    }
    flush()
  }

  func probe(x: Double, y: Double) {
    guard let position = AbsolutePosition.map(x: x, y: y, width: 1, height: 1) else { return }
    release()
    sendAbsolute(buttons: 0, position: position)
  }

  func release() {
    transport.release()
    absoluteTransport.release()
    flush()
  }

  private func flush() {
    guard let manager, let target, let report else { return }
    if activeAbsolute {
      absoluteTransport.drain {
        manager.updateValue($0.data, for: report, onSubscribedCentrals: [target])
      }
    } else {
      transport.drain { manager.updateValue($0.data, for: report, onSubscribedCentrals: [target]) }
    }
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    guard peripheral === manager else { return }
    guard peripheral.state == .poweredOn else {
      discoveryStatus = "蓝牙不可用，尚未建立鼠标连接"
      connected = false
      target = nil
      report = nil
      services = []
      transport.release()
      absoluteTransport.release()
      onReset?()
      switch peripheral.state {
      case .poweredOff: status = "请打开 Mac 蓝牙"
      case .unauthorized: status = "请在系统设置允许本原型使用蓝牙"
      case .unsupported: status = "此 Mac 不支持 BLE 外设模式"
      default: status = "蓝牙暂不可用"
      }
      return
    }
    install(peripheral)
  }

  private func install(_ peripheral: CBPeripheralManager) {
    peripheral.removeAllServices()
    registeredServices = 0
    suspended = false
    let battery = CBMutableService(type: uuid("180F"), primary: true)
    battery.characteristics = [
      CBMutableCharacteristic(
        type: uuid("2A19"), properties: .read,
        value: Data([100]), permissions: .readable)
    ]
    let information = CBMutableService(type: uuid("180A"), primary: true)
    information.characteristics = [
      CBMutableCharacteristic(
        type: uuid("2A29"), properties: .read,
        value: Data("LiveMate Lab".utf8), permissions: .readable),
      // Prototype identity only; 0xFFFF is not a production vendor assignment.
      CBMutableCharacteristic(
        type: uuid("2A50"), properties: .read,
        value: Data([0x01, 0xFF, 0xFF, activeAbsolute ? 0x02 : 0x01, 0x00, 0x00, 0x01]),
        permissions: .readable),
    ]
    let hid = CBMutableService(type: uuid("1812"), primary: true)
    // Standard three-button relative mouse; Report Reference supplies ID 1.
    let relativeDescriptor: [UInt8] = [
      0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0x85, 0x01, 0x09, 0x01, 0xA1, 0x00,
      0x05, 0x09, 0x19, 0x01, 0x29, 0x03, 0x15, 0x00, 0x25, 0x01, 0x95, 0x03,
      0x75, 0x01, 0x81, 0x02, 0x95, 0x01, 0x75, 0x05, 0x81, 0x03, 0x05, 0x01,
      0x09, 0x30, 0x09, 0x31, 0x09, 0x38, 0x15, 0x81, 0x25, 0x7F, 0x75, 0x08,
      0x95, 0x03, 0x81, 0x06, 0xC0, 0xC0,
    ]
    // Three buttons, two 16-bit absolute axes (0...32767), one relative wheel.
    // This is an absolute mouse, not a touchscreen or a multi-touch digitizer.
    let absoluteDescriptor: [UInt8] = [
      0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0x85, 0x01, 0x09, 0x01, 0xA1, 0x00,
      0x05, 0x09, 0x19, 0x01, 0x29, 0x03, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01,
      0x95, 0x03, 0x81, 0x02, 0x75, 0x05, 0x95, 0x01, 0x81, 0x03,
      0x05, 0x01, 0x09, 0x30, 0x09, 0x31, 0x15, 0x00, 0x26, 0xFF, 0x7F,
      0x75, 0x10, 0x95, 0x02, 0x81, 0x02,
      0x09, 0x38, 0x15, 0x81, 0x25, 0x7F, 0x75, 0x08, 0x95, 0x01, 0x81, 0x06,
      0xC0, 0xC0,
    ]
    let descriptor = activeAbsolute ? absoluteDescriptor : relativeDescriptor
    let input = CBMutableCharacteristic(
      type: uuid("2A4D"),
      properties: [.read, .notify, .notifyEncryptionRequired], value: nil,
      permissions: [.readEncryptionRequired])
    input.descriptors = [CBMutableDescriptor(type: CBUUID(string: "2908"), value: Data([1, 1]))]
    report = input
    hid.characteristics = [
      CBMutableCharacteristic(
        type: uuid("2A4A"), properties: .read,
        value: Data([0x11, 0x01, 0x00, 0x02]), permissions: .readable),
      CBMutableCharacteristic(
        type: uuid("2A4B"), properties: .read,
        value: Data(descriptor), permissions: .readable),
      CBMutableCharacteristic(
        type: uuid("2A4C"), properties: .writeWithoutResponse,
        value: nil, permissions: .writeEncryptionRequired),
      input,
    ]
    services = [battery, information, hid]
    status = "正在注册鼠标服务…"
    peripheral.add(services.removeFirst())
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?
  ) {
    guard peripheral === manager else { return }
    guard error == nil else {
      stop()
      status = "系统拒绝注册蓝牙服务：\(error!.localizedDescription)"
      return
    }
    registeredServices += 1
    discoveryStatus = "服务注册 \(registeredServices)/3；尚未建立鼠标连接"
    if !services.isEmpty {
      peripheral.add(services.removeFirst())
      return
    }
    peripheral.startAdvertising([
      CBAdvertisementDataLocalNameKey: activeAbsolute ? "LM Abs" : "LM Mouse",
      CBAdvertisementDataServiceUUIDsKey: [
        advertisingCompact ? CBUUID(string: "1812") : uuid("1812")
      ],
    ])
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    guard peripheral === manager else { return }
    if let error {
      stop()
      status = "无法广播鼠标：\(error.localizedDescription)"
    } else {
      status = "等待 iPhone 配对：\(activeAbsolute ? "LM Abs" : "LM Mouse")（也可能显示 Mac 名称）"
      discoveryStatus = "服务 3/3 · 系统广播\(peripheral.isAdvertising ? "已开启" : "未开启") · 尚未订阅"
    }
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, central: CBCentral,
    didSubscribeTo characteristic: CBCharacteristic
  ) {
    guard peripheral === manager, characteristic === report,
      targetID == nil || targetID == central.identifier
    else { return }
    targetID = central.identifier
    target = central
    suspended = false
    peripheral.stopAdvertising()
    transport.release()
    absoluteTransport.reset()
    flush()
    connected = true
    discoveryStatus = "鼠标输入已订阅"
    status = "iPhone 已订阅鼠标输入；可开启控制"
    onReset?()
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, central: CBCentral,
    didUnsubscribeFrom characteristic: CBCharacteristic
  ) {
    guard peripheral === manager, characteristic === report, central.identifier == targetID else {
      return
    }
    target = nil
    connected = false
    discoveryStatus = "鼠标订阅已断开"
    transport.release()
    absoluteTransport.release()
    onReset?()
    status = "手机已断开；停止并重新开始配对可重试"
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
    guard peripheral === manager else { return }
    flush()
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
    guard peripheral === manager else { return }
    guard targetID == nil || request.central.identifier == targetID else {
      peripheral.respond(to: request, withResult: .insufficientAuthorization)
      return
    }
    guard request.characteristic === report else {
      peripheral.respond(to: request, withResult: .readNotPermitted)
      return
    }
    let value =
      activeAbsolute
      ? absoluteTransport.stateData
      : MouseReport(buttons: transport.buttons, x: 0, y: 0, wheel: 0).data
    guard request.offset <= value.count else {
      peripheral.respond(to: request, withResult: .invalidOffset)
      return
    }
    request.value = value.subdata(in: request.offset..<value.count)
    peripheral.respond(to: request, withResult: .success)
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]
  ) {
    guard peripheral === manager else { return }
    guard let first = requests.first else { return }
    guard
      requests.allSatisfy({
        (targetID == nil || $0.central.identifier == targetID)
          && $0.characteristic.uuid == uuid("2A4C") && $0.offset == 0 && $0.value?.count == 1
          && ($0.value?.first ?? 255) <= 1
      })
    else {
      peripheral.respond(to: first, withResult: .requestNotSupported)
      return
    }
    for request in requests {
      suspended = request.value?.first == 0
      connected = !suspended && target != nil
      if suspended {
        release()
        onReset?()
        status = "手机暂停了鼠标输入"
      } else {
        status = "手机已恢复鼠标输入，请重新开启控制"
      }
    }
    peripheral.respond(to: first, withResult: .success)
  }
}
