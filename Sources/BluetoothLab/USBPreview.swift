@preconcurrency import AVFoundation
import AppKit
import Combine
import QuartzCore

/// Session and delegate run on one serial queue; only the latest frame crosses the lock.
final class CaptureWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
  @unchecked Sendable
{
  struct Snapshot {
    let frame: CMSampleBuffer?
    let time: TimeInterval
    let status: String
  }
  private let queue = DispatchQueue(label: "com.tinyq.bluetoothlab.capture")
  private let lock = NSLock()
  private var frame: CMSampleBuffer?
  private var time: TimeInterval = 0
  private var status = "USB 预览尚未连接"
  private var generation = 0
  private var outputGeneration = -1
  private var session: AVCaptureSession?
  private var output: AVCaptureVideoDataOutput?

  func take() -> Snapshot {
    lock.lock()
    defer { lock.unlock() }
    let result = Snapshot(frame: frame, time: time, status: status)
    frame = nil
    return result
  }

  private func setStatus(_ text: String) {
    lock.lock()
    status = text
    lock.unlock()
  }

  func start() {
    lock.lock()
    generation += 1
    let epoch = generation
    frame = nil
    time = 0
    lock.unlock()
    queue.async { [self] in
      lock.lock()
      let current = generation
      lock.unlock()
      guard current == epoch else { return }
      guard session == nil else { return }
      setStatus("正在查找 USB iPhone…")
      do {
        let devices = try CoreMediaIODeviceDiscovery().discoverWiredScreenDevices()
        guard devices.count == 1, let device = devices.first else {
          setStatus(devices.isEmpty ? "未发现 iPhone；请接入 USB、解锁并信任此 Mac" : "发现多台设备；请只连接一台 iPhone")
          return
        }
        let capture = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device.value)
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        video.setSampleBufferDelegate(self, queue: queue)
        capture.beginConfiguration()
        guard capture.canAddInput(input), capture.canAddOutput(video) else {
          capture.commitConfiguration()
          setStatus("设备暂不可用，请先断开主程序的手机预览")
          return
        }
        capture.addInputWithNoConnections(input)
        capture.addOutputWithNoConnections(video)
        let videoPorts = input.ports.filter { $0.mediaType == .video }
        let ports = videoPorts.isEmpty ? input.ports.filter { $0.mediaType == .muxed } : videoPorts
        guard !ports.isEmpty else {
          capture.commitConfiguration()
          setStatus("设备没有视频通道")
          return
        }
        let connection = AVCaptureConnection(inputPorts: ports, output: video)
        guard capture.canAddConnection(connection) else {
          capture.commitConfiguration()
          setStatus("无法建立视频连接")
          return
        }
        capture.addConnection(connection)
        capture.commitConfiguration()
        session = capture
        output = video
        outputGeneration = epoch
        capture.startRunning()
        setStatus("等待手机画面…")
      } catch { setStatus("连接失败：\(error.localizedDescription)") }
    }
  }

  func stop() {
    lock.lock()
    generation += 1
    frame = nil
    time = 0
    lock.unlock()
    queue.async { [self] in
      output?.setSampleBufferDelegate(nil, queue: nil)
      session?.stopRunning()
      session = nil
      output = nil
      lock.lock()
      frame = nil
      time = 0
      status = "USB 预览已停止"
      lock.unlock()
    }
  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard output === self.output else { return }
    lock.lock()
    guard outputGeneration == generation else {
      lock.unlock()
      return
    }
    frame = sampleBuffer
    time = ProcessInfo.processInfo.systemUptime
    status = "USB 视频已连接（无音频）"
    lock.unlock()
  }
}

@MainActor
final class LabModel: ObservableObject {
  let bluetooth = BluetoothMouse()
  let capture = CaptureWorker()
  @Published var usbStatus = "USB 预览尚未连接"
  @Published var armed = false { didSet { if !armed { surface?.releaseInput() } } }
  @Published var sensitivity = 1.0
  @Published var fresh = false
  @Published var usbRequested = false
  weak var surface: PhoneSurface?
  private var timer: Timer?
  private var observers: [NSObjectProtocol] = []
  private var permissionGeneration = 0

  init() {
    bluetooth.onReset = { [weak self] in self?.armed = false }
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didResignActiveNotification,
        object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.armed = false }
      })
    observers.append(
      NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.willSleepNotification,
        object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.armed = false }
      })
  }

  private func tick() {
    let snapshot = capture.take()
    let nextFresh =
      usbRequested && snapshot.time > 0
      && ProcessInfo.processInfo.systemUptime - snapshot.time < 0.6
    if fresh && !nextFresh {
      armed = false
      surface?.clear()
    }
    if fresh != nextFresh { fresh = nextFresh }
    let displayStatus = snapshot.time > 0 && !nextFresh ? "画面已中断，手机控制已停用" : snapshot.status
    if usbRequested, usbStatus != displayStatus { usbStatus = displayStatus }
    if usbRequested, let frame = snapshot.frame, nextFresh { surface?.present(frame) }
    surface?.syncCursorVisibility()
  }

  func connectUSB() {
    let alert = NSAlert()
    alert.messageText = "连接独立原型的 USB 预览？"
    alert.informativeText = "请先在另一个窗口的主程序中断开手机预览，避免争用设备。这里只显示一台 USB iPhone 的视频，不采集声音、不保存画面。"
    alert.addButton(withTitle: "连接预览")
    alert.addButton(withTitle: "取消")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    permissionGeneration += 1
    let generation = permissionGeneration
    usbRequested = true
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: capture.start()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
        Task { @MainActor in
          guard let self, self.permissionGeneration == generation, self.usbRequested else { return }
          if allowed {
            self.capture.start()
          } else {
            self.usbRequested = false
            self.usbStatus = "相机权限未允许"
          }
        }
      }
    default:
      usbRequested = false
      usbStatus = "请在系统设置允许本原型使用相机"
    }
  }

  func stopUSB() {
    permissionGeneration += 1
    usbRequested = false
    armed = false
    fresh = false
    usbStatus = "USB 预览已停止"
    capture.stop()
    surface?.clear()
  }

  func shutdown() {
    stopUSB()
    bluetooth.stop()
    timer?.invalidate()
    timer = nil
  }
}
