import Foundation

public struct MouseReport: Equatable, Sendable {
  public var buttons: UInt8
  public var x: Int8
  public var y: Int8
  public var wheel: Int8
  public static let released = MouseReport(buttons: 0, x: 0, y: 0, wheel: 0)
  public init(buttons: UInt8, x: Int8, y: Int8, wheel: Int8) {
    self.buttons = buttons & 7
    self.x = x
    self.y = y
    self.wheel = wheel
  }
  public var data: Data {
    Data([buttons, UInt8(bitPattern: x), UInt8(bitPattern: y), UInt8(bitPattern: wheel)])
  }
}

/// A bounded FIFO: a failed BLE write must leave the head in place.
public struct MouseTransport: Sendable {
  public private(set) var pending: [MouseReport] = []
  public private(set) var buttons: UInt8 = 0
  private var fractionX = 0.0
  private var fractionY = 0.0
  private var fractionWheel = 0.0
  public let capacity: Int
  public init(capacity: Int = 256) { self.capacity = max(1, capacity) }

  @discardableResult
  public mutating func enqueue(buttons: UInt8, x: Double = 0, y: Double = 0, wheel: Double = 0)
    -> Bool
  {
    guard x.isFinite, y.isFinite, wheel.isFinite,
      abs(x) <= 16000, abs(y) <= 16000, abs(wheel) <= 16000
    else {
      release()
      return false
    }
    let nextButtons = buttons & 7
    fractionX += x
    fractionY += y
    fractionWheel += wheel
    var dx = Int(fractionX)
    var dy = Int(fractionY)
    var dw = Int(fractionWheel)
    fractionX -= Double(dx)
    fractionY -= Double(dy)
    fractionWheel -= Double(dw)
    let count = max(1, (max(abs(dx), abs(dy), abs(dw)) + 126) / 127)
    if dx == 0, dy == 0, dw == 0, nextButtons == self.buttons { return true }
    guard pending.count + count <= capacity else {
      release()
      return false
    }
    for _ in 0..<count {
      let sx = max(-127, min(127, dx))
      let sy = max(-127, min(127, dy))
      let sw = max(-127, min(127, dw))
      pending.append(MouseReport(buttons: nextButtons, x: Int8(sx), y: Int8(sy), wheel: Int8(sw)))
      dx -= sx
      dy -= sy
      dw -= sw
    }
    self.buttons = nextButtons
    return true
  }

  public mutating func release() {
    buttons = 0
    fractionX = 0
    fractionY = 0
    fractionWheel = 0
    pending = [.released]
  }

  public mutating func drain(send: (MouseReport) -> Bool) {
    while let first = pending.first {
      guard send(first) else { return }
      pending.removeFirst()
    }
  }
}
