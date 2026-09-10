import Combine
@preconcurrency import CoreBluetooth
import Foundation
import PhoneControlCore

@MainActor
// CoreBluetooth is explicitly configured to deliver every delegate callback on .main.
final class BluetoothMouse: NSObject, ObservableObject, @preconcurrency CBPeripheralManagerDelegate
{
  @Published private(set) var status = "Bluetooth is off"
  @Published private(set) var connected = false
  @Published private(set) var running = false
  @Published var compactDiscovery = true
  @Published private(set) var discoveryStatus = "No services registered"
  private var advertisingCompact = true
  private var registeredServices = 0
  var onReset: (() -> Void)?
  private var manager: CBPeripheralManager?
  private var target: CBCentral?
  private var targetID: UUID?
  private var report: CBMutableCharacteristic?
  private var services: [CBMutableService] = []
  private var absoluteTransport = AbsoluteTransport()
  private var suspended = false

  private func uuid(_ short: String) -> CBUUID {
    CBUUID(string: "0000\(short)-0000-1000-8000-00805F9B34FB")
  }

  func start() {
    guard !running else { return }
    running = true
    absoluteTransport.reset()
    advertisingCompact = compactDiscovery
    registeredServices = 0
    discoveryStatus = "Preparing mouse service"
    status = "Starting Bluetooth…"
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
    discoveryStatus = "Advertising stopped"
    status = "Bluetooth stopped"
  }

  func sendAbsolute(buttons: UInt8, position: AbsolutePosition, wheel: Double = 0) {
    guard connected, !suspended else { return }
    if !absoluteTransport.enqueue(buttons: buttons, position: position, wheel: wheel) {
      status = "Input queue reset. Enable control again."
      onReset?()
    }
    flush()
  }

  func release() {
    absoluteTransport.release()
    flush()
  }

  private func flush() {
    guard let manager, let target, let report else { return }
    absoluteTransport.drain {
      manager.updateValue($0.data, for: report, onSubscribedCentrals: [target])
    }
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    guard peripheral === manager else { return }
    guard peripheral.state == .poweredOn else {
      discoveryStatus = "Bluetooth unavailable; mouse disconnected"
      connected = false
      target = nil
      report = nil
      services = []
      absoluteTransport.release()
      onReset?()
      switch peripheral.state {
      case .poweredOff: status = "Turn on Bluetooth on your Mac"
      case .unauthorized: status = "Allow GlassTether to use Bluetooth in System Settings"
      case .unsupported: status = "This Mac does not support BLE peripheral mode"
      default: status = "Bluetooth is unavailable"
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
        value: Data("GlassTether Preview".utf8), permissions: .readable),
      // Prototype identity only; 0xFFFF is not a production vendor assignment.
      CBMutableCharacteristic(
        type: uuid("2A50"), properties: .read,
        value: Data([0x01, 0xFF, 0xFF, 0x03, 0x00, 0x00, 0x01]),
        permissions: .readable),
    ]
    let hid = CBMutableService(type: uuid("1812"), primary: true)
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
    let descriptor = absoluteDescriptor
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
    status = "Registering mouse service…"
    peripheral.add(services.removeFirst())
  }

  func peripheralManager(
    _ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?
  ) {
    guard peripheral === manager else { return }
    guard error == nil else {
      stop()
      status = "Bluetooth service rejected: \(error!.localizedDescription)"
      return
    }
    registeredServices += 1
    discoveryStatus = "Services registered: \(registeredServices)/3; waiting for a mouse connection"
    if !services.isEmpty {
      peripheral.add(services.removeFirst())
      return
    }
    peripheral.startAdvertising([
      CBAdvertisementDataLocalNameKey: "GT Mouse",
      CBAdvertisementDataServiceUUIDsKey: [
        advertisingCompact ? CBUUID(string: "1812") : uuid("1812")
      ],
    ])
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    guard peripheral === manager else { return }
    if let error {
      stop()
      status = "Could not advertise mouse: \(error.localizedDescription)"
    } else {
      status = "Pair on iPhone: GT Mouse (your Mac name may appear instead)"
      discoveryStatus =
        "Services 3/3 · advertising \(peripheral.isAdvertising ? "on" : "off") · waiting for subscription"
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
    absoluteTransport.reset()
    flush()
    connected = true
    discoveryStatus = "Mouse input subscribed"
    status = "Mouse connected. Ready when video is connected."
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
    discoveryStatus = "Mouse disconnected"
    absoluteTransport.release()
    onReset?()
    status = "Mouse disconnected. Stop Bluetooth and pair again."
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
    let value = absoluteTransport.stateData
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
        status = "iPhone suspended mouse input"
      } else {
        status = "Mouse resumed. Enable control again."
      }
    }
    peripheral.respond(to: first, withResult: .success)
  }
}
