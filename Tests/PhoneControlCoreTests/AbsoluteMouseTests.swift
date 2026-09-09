import Testing

@testable import PhoneControlCore

@Test func repeatedAbsoluteTargetStillSendsReport() {
  var queue = AbsoluteTransport()
  queue.enqueue(buttons: 0, position: .center)
  queue.drain { _ in true }
  queue.enqueue(buttons: 0, position: .center)
  #expect(queue.pending == [AbsoluteReport(buttons: 0, position: .center)])
}

@Test func absoluteMappingUsesVideoRectAndIsScaleIndependent() {
  #expect(AbsolutePosition.map(x: 0, y: 0, width: 300, height: 600) == AbsolutePosition(x: 0, y: 0))
  #expect(
    AbsolutePosition.map(x: 300, y: 600, width: 300, height: 600)
      == AbsolutePosition(x: 32767, y: 32767))
  #expect(AbsolutePosition.map(x: 150, y: 300, width: 300, height: 600) == .center)
  #expect(AbsolutePosition.map(x: 300, y: 600, width: 600, height: 1200) == .center)
  #expect(AbsolutePosition.map(x: -1, y: 100, width: 300, height: 600) == nil)
  #expect(AbsolutePosition.map(x: 20, y: 20, width: 0, height: 600) == nil)
  #expect(AbsolutePosition.map(x: .nan, y: 20, width: 300, height: 600) == nil)
}

@Test func absoluteReportHasSixLittleEndianBytesWithoutReportID() {
  let report = AbsoluteReport(
    buttons: 1, position: AbsolutePosition(x: 0x1234, y: 32767), wheel: -1)
  #expect(Array(report.data) == [1, 0x34, 0x12, 0xFF, 0x7F, 0xFF])
}

@Test func absoluteBackpressurePreservesClickLocationAndRelease() {
  var queue = AbsoluteTransport()
  let start = AbsolutePosition(x: 100, y: 200)
  let end = AbsolutePosition(x: 300, y: 400)
  queue.enqueue(buttons: 0, position: start)
  queue.enqueue(buttons: 1, position: start)
  queue.enqueue(buttons: 1, position: end)
  queue.enqueue(buttons: 0, position: end)
  queue.drain { _ in false }
  #expect(queue.pending.map(\.buttons) == [0, 1, 1, 0])
  #expect(queue.pending.map(\.position) == [start, start, end, end])
  queue.release()
  #expect(queue.pending == [AbsoluteReport(buttons: 0, position: end)])
  queue.drain { _ in true }
  #expect(queue.pending.isEmpty)
}

@Test func absoluteOverflowDisarmsWithoutJumpingToOrigin() {
  var queue = AbsoluteTransport(capacity: 1)
  let location = AbsolutePosition(x: 200, y: 400)
  queue.enqueue(buttons: 1, position: location)
  let accepted = queue.enqueue(buttons: 1, position: .center)
  #expect(!accepted)
  #expect(queue.pending == [AbsoluteReport(buttons: 0, position: location)])
  #expect(queue.buttons == 0)
}
