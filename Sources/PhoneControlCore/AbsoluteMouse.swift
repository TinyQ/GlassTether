import Foundation

/// Normalized screen coordinates, with the origin at the top-left of the visible video.
public struct AbsolutePosition: Equatable, Sendable {
  public let x: UInt16
  public let y: UInt16
  public static let center = AbsolutePosition(x: 16384, y: 16384)

  public init(x: UInt16, y: UInt16) {
    self.x = min(x, 32767)
    self.y = min(y, 32767)
  }

  public static func map(x: Double, y: Double, width: Double, height: Double) -> Self? {
    guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
      width > 0, height > 0, x >= 0, y >= 0, x <= width, y <= height
    else { return nil }
    return Self(
      x: UInt16((x / width * 32767).rounded()),
      y: UInt16((y / height * 32767).rounded()))
  }
}

public struct AbsoluteReport: Equatable, Sendable {
  public let buttons: UInt8
  public let position: AbsolutePosition
  public let wheel: Int8
  public init(buttons: UInt8, position: AbsolutePosition, wheel: Int8 = 0) {
    self.buttons = buttons & 7
    self.position = position
    self.wheel = wheel
  }
  public var data: Data {
    Data([
      buttons, UInt8(position.x & 255), UInt8(position.x >> 8),
      UInt8(position.y & 255), UInt8(position.y >> 8), UInt8(bitPattern: wheel),
    ])
  }
}

/// Separate from the proven relative transport so neither wire format can be mixed.
public struct AbsoluteTransport: Sendable {
  public private(set) var pending: [AbsoluteReport] = []
  public private(set) var position = AbsolutePosition.center
  public private(set) var buttons: UInt8 = 0
  private var wheelFraction = 0.0
  private let capacity: Int
  public init(capacity: Int = 256) { self.capacity = max(1, capacity) }

  @discardableResult
  public mutating func enqueue(buttons: UInt8, position: AbsolutePosition, wheel: Double = 0)
    -> Bool
  {
    guard wheel.isFinite, abs(wheel) <= 16000 else {
      release()
      return false
    }
    wheelFraction += wheel
    var remaining = Int(wheelFraction)
    wheelFraction -= Double(remaining)
    let nextButtons = buttons & 7
    // Repeat coordinates too: another physical pointer may have moved the host cursor.
    let count = max(1, (abs(remaining) + 126) / 127)
    guard pending.count + count <= capacity else {
      release()
      return false
    }
    for _ in 0..<count {
      let part = max(-127, min(127, remaining))
      pending.append(AbsoluteReport(buttons: nextButtons, position: position, wheel: Int8(part)))
      remaining -= part
    }
    self.buttons = nextButtons
    self.position = position
    return true
  }

  public mutating func release() {
    buttons = 0
    wheelFraction = 0
    // Release at the last requested point, never jump to (0, 0) on exit.
    pending = [AbsoluteReport(buttons: 0, position: position)]
  }

  public mutating func reset() {
    position = .center
    release()
  }

  public var stateData: Data { AbsoluteReport(buttons: buttons, position: position).data }

  public mutating func drain(send: (AbsoluteReport) -> Bool) {
    while let first = pending.first {
      guard send(first) else { return }
      pending.removeFirst()
    }
  }
}
