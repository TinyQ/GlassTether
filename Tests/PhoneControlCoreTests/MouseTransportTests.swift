import Testing

@testable import PhoneControlCore

@Test func largeMovementIsLosslesslySplit() {
  var queue = MouseTransport()
  let accepted = queue.enqueue(buttons: 1, x: 300, y: -280, wheel: 2)
  #expect(accepted)
  #expect(queue.pending.count == 3)
  #expect(queue.pending.reduce(0) { $0 + Int($1.x) } == 300)
  #expect(queue.pending.reduce(0) { $0 + Int($1.y) } == -280)
  #expect(queue.pending.allSatisfy { $0.buttons == 1 })
}

@Test func backpressurePreservesClickOrder() {
  var queue = MouseTransport()
  queue.enqueue(buttons: 1)
  queue.enqueue(buttons: 0)
  queue.drain { _ in false }
  #expect(queue.pending.map(\.buttons) == [1, 0])
  var delivered: [UInt8] = []
  queue.drain {
    delivered.append($0.buttons)
    return delivered.count == 1
  }
  #expect(queue.pending.map(\.buttons) == [0])
  queue.drain { _ in true }
  #expect(queue.pending.isEmpty)
}

@Test func releaseDropsOldMovementAndClearsFractions() {
  var queue = MouseTransport()
  queue.enqueue(buttons: 1, x: 10.8)
  queue.release()
  #expect(queue.pending == [.released])
  #expect(queue.buttons == 0)
  queue.drain { _ in true }
  queue.enqueue(buttons: 0, x: 0.3)
  #expect(queue.pending.isEmpty)
}

@Test func overflowAndInvalidInputFailClosed() {
  var queue = MouseTransport(capacity: 2)
  let overflow = queue.enqueue(buttons: 1, x: 400)
  #expect(!overflow)
  #expect(queue.pending == [.released])
  let invalid = queue.enqueue(buttons: 1, x: .infinity)
  #expect(!invalid)
  #expect(queue.buttons == 0)
}

@Test func subpixelMotionAccumulatesAndReportUsesSignedBytes() {
  var queue = MouseTransport()
  for _ in 0..<4 { queue.enqueue(buttons: 0, x: 0.3, y: -0.3) }
  #expect(queue.pending.count == 1)
  #expect(Array(queue.pending[0].data) == [0, 1, 255, 0])
}
