@preconcurrency import AVFoundation
import AppKit
import PhoneControlCore
import SwiftUI

@MainActor
final class PhoneSurface: NSView {
  weak var model: SessionModel?
  private let video = AVSampleBufferDisplayLayer()
  private var imageSize = CGSize.zero
  private var imageRect = CGRect.zero
  private var tracking: NSTrackingArea?
  private var lastPoint: CGPoint?
  private var buttons: UInt8 = 0
  private var blockedUntilExit = false
  private var entered = false
  private var ownsCursorHide = false
  override var isFlipped: Bool { true }
  override var acceptsFirstResponder: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
    video.videoGravity = .resizeAspect
    layer?.addSublayer(video)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }

  func present(_ sample: CMSampleBuffer) {
    guard let description = CMSampleBufferGetFormatDescription(sample) else { return }
    let dimensions = CMVideoFormatDescriptionGetDimensions(description)
    let next = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
    if next != imageSize {
      releaseInput()
      imageSize = next
      needsLayout = true
    }
    if video.status == .failed { video.flush() }
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) {
      let item = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
      CFDictionarySetValue(
        item, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
    }
    if video.isReadyForMoreMediaData { video.enqueue(sample) }
  }

  func clear() {
    releaseInput()
    video.flushAndRemoveImage()
    imageSize = .zero
    needsLayout = true
  }

  override func layout() {
    super.layout()
    let old = imageRect
    if imageSize.width > 0 && imageSize.height > 0 {
      let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
      let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
      imageRect = CGRect(
        x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
        width: size.width, height: size.height)
    } else {
      imageRect = .zero
    }
    if old != imageRect { releaseInput() }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    video.frame = bounds
    CATransaction.commit()
    updateTrackingAreas()
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let tracking { removeTrackingArea(tracking) }
    guard !imageRect.isEmpty else {
      tracking = nil
      return
    }
    let area = NSTrackingArea(
      rect: imageRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
      owner: self, userInfo: nil)
    addTrackingArea(area)
    tracking = area
  }

  private var canSend: Bool {
    model?.armed == true && model?.fresh == true && model?.bluetooth.connected == true
      && !blockedUntilExit && NSApp.isActive && window?.isKeyWindow == true
  }

  func releaseInput() {
    setMacCursorHidden(false)
    buttons = 0
    lastPoint = nil
    model?.bluetooth.release()
  }

  // NSCursor uses a hide count. Only balance the hide owned by this view.
  private func setMacCursorHidden(_ hidden: Bool) {
    guard hidden != ownsCursorHide else { return }
    ownsCursorHide = hidden
    if hidden { NSCursor.hide() } else { NSCursor.unhide() }
  }

  func syncCursorVisibility() {
    guard canSend, entered, NSApp.isActive, let window,
      window.isKeyWindow, window.isVisible, !window.isMiniaturized
    else {
      setMacCursorHidden(false)
      return
    }
    let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
    setMacCursorHidden(imageRect.contains(point))
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    releaseInput()
    entered = false
    super.viewWillMove(toWindow: newWindow)
  }

  override func mouseEntered(with event: NSEvent) {
    entered = true
    blockedUntilExit = NSEvent.pressedMouseButtons != 0
    lastPoint = convert(event.locationInWindow, from: nil)
    if canSend {
      window?.makeFirstResponder(self)
      if let position = absolutePosition(for: event) {
        model?.bluetooth.sendAbsolute(buttons: 0, position: position)
      }
    }
    syncCursorVisibility()
  }
  override func mouseExited(with event: NSEvent) {
    entered = false
    releaseInput()
    blockedUntilExit = false
  }
  override func mouseMoved(with event: NSEvent) { move(event) }
  override func mouseDragged(with event: NSEvent) { move(event) }
  override func rightMouseDragged(with event: NSEvent) { move(event) }
  override func otherMouseDragged(with event: NSEvent) { move(event) }

  private func move(_ event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard imageRect.contains(point), entered else {
      releaseInput()
      return
    }
    guard canSend else {
      setMacCursorHidden(false)
      lastPoint = point
      return
    }
    window?.makeFirstResponder(self)
    syncCursorVisibility()
    if let position = absolutePosition(for: event) {
      model?.bluetooth.sendAbsolute(buttons: buttons, position: position)
    }
    lastPoint = point
  }

  private func button(_ event: NSEvent, down: Bool) {
    guard canSend, entered, imageRect.contains(convert(event.locationInWindow, from: nil)),
      event.buttonNumber < 3
    else {
      if !down { releaseInput() }
      return
    }
    let bit = UInt8(1 << event.buttonNumber)
    if down { buttons |= bit } else { buttons &= ~bit }
    if let position = absolutePosition(for: event) {
      model?.bluetooth.sendAbsolute(buttons: buttons, position: position)
    }
  }

  override func mouseDown(with event: NSEvent) { button(event, down: true) }
  override func mouseUp(with event: NSEvent) { button(event, down: false) }
  override func rightMouseDown(with event: NSEvent) { button(event, down: true) }
  override func rightMouseUp(with event: NSEvent) { button(event, down: false) }
  override func otherMouseDown(with event: NSEvent) { button(event, down: true) }
  override func otherMouseUp(with event: NSEvent) { button(event, down: false) }
  override func scrollWheel(with event: NSEvent) {
    guard canSend, entered, imageRect.contains(convert(event.locationInWindow, from: nil)),
      event.momentumPhase.isEmpty
    else { return }
    let scale = event.hasPreciseScrollingDeltas ? 0.05 : 1.0
    if let position = absolutePosition(for: event) {
      model?.bluetooth.sendAbsolute(
        buttons: buttons, position: position, wheel: event.scrollingDeltaY * scale)
    }
  }

  private func absolutePosition(for event: NSEvent) -> AbsolutePosition? {
    let point = convert(event.locationInWindow, from: nil)
    return AbsolutePosition.map(
      x: point.x - imageRect.minX, y: point.y - imageRect.minY,
      width: imageRect.width, height: imageRect.height)
  }
  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      blockedUntilExit = true
      releaseInput()
      model?.armed = false
    } else {
      super.keyDown(with: event)
    }
  }
}

struct PhonePreview: NSViewRepresentable {
  let model: SessionModel
  func makeNSView(context: Context) -> PhoneSurface {
    let surface = PhoneSurface()
    surface.model = model
    model.surface = surface
    return surface
  }
  func updateNSView(_ nsView: PhoneSurface, context: Context) {}
  static func dismantleNSView(_ nsView: PhoneSurface, coordinator: ()) { nsView.releaseInput() }
}
