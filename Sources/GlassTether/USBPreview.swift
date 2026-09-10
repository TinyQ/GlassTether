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
  private let queue = DispatchQueue(label: "local.glasstether.preview.capture")
  private let lock = NSLock()
  private var frame: CMSampleBuffer?
  private var time: TimeInterval = 0
  private var status = "USB preview is off"
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
      setStatus("Looking for a wired iPhone…")
      do {
        let devices = try CoreMediaIODeviceDiscovery().discoverWiredScreenDevices()
        guard devices.count == 1, let device = devices.first else {
          setStatus(
            devices.isEmpty
              ? "No iPhone found. Connect USB, unlock, and trust this Mac."
              : "Multiple devices found. Connect only one iPhone.")
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
          setStatus("Device unavailable. Disconnect preview in other apps.")
          return
        }
        capture.addInputWithNoConnections(input)
        capture.addOutputWithNoConnections(video)
        let videoPorts = input.ports.filter { $0.mediaType == .video }
        let ports = videoPorts.isEmpty ? input.ports.filter { $0.mediaType == .muxed } : videoPorts
        guard !ports.isEmpty else {
          capture.commitConfiguration()
          setStatus("Device has no video channel")
          return
        }
        let connection = AVCaptureConnection(inputPorts: ports, output: video)
        guard capture.canAddConnection(connection) else {
          capture.commitConfiguration()
          setStatus("Could not establish a video connection")
          return
        }
        capture.addConnection(connection)
        capture.commitConfiguration()
        session = capture
        output = video
        outputGeneration = epoch
        capture.startRunning()
        setStatus("Waiting for iPhone video…")
      } catch { setStatus("Connection failed: \(error.localizedDescription)") }
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
      status = "USB preview stopped"
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
    status = "USB video connected · no audio"
    lock.unlock()
  }
}
