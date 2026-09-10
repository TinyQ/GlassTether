@preconcurrency import AVFoundation
import AppKit
import Combine
import PhoneControlCore

@MainActor
final class SessionModel: ObservableObject {
  let bluetooth = BluetoothMouse()
  let capture = CaptureWorker()
  @Published var usbStatus = "USB preview is off"
  @Published var armed = false { didSet { if !armed { surface?.releaseInput() } } }
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
      FrameFreshness.isFresh(
        requested: usbRequested, frameTime: snapshot.time, now: ProcessInfo.processInfo.systemUptime
      )
    if fresh && !nextFresh {
      armed = false
      surface?.clear()
    }
    if fresh != nextFresh { fresh = nextFresh }
    let displayStatus =
      snapshot.time > 0 && !nextFresh ? "Video interrupted. Control is off." : snapshot.status
    if usbRequested, usbStatus != displayStatus { usbStatus = displayStatus }
    if usbRequested, let frame = snapshot.frame, nextFresh { surface?.present(frame) }
    if armed
      && (!bluetooth.connected || !nextFresh || !NSApp.isActive
        || surface?.window?.isKeyWindow != true)
    {
      armed = false
    }
    surface?.syncCursorVisibility()
  }

  func connectUSB() {
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
            self.usbStatus = "Camera access denied. Allow it in System Settings, then retry."
          }
        }
      }
    default:
      usbRequested = false
      usbStatus = "Allow GlassTether to use the camera in System Settings, then retry."
    }
  }

  func stopUSB() {
    permissionGeneration += 1
    usbRequested = false
    armed = false
    fresh = false
    usbStatus = "USB preview stopped"
    capture.stop()
    surface?.clear()
  }

  func retryUSB() {
    stopUSB()
    connectUSB()
  }

  func shutdown() {
    stopUSB()
    bluetooth.stop()
    timer?.invalidate()
    timer = nil
  }
}
