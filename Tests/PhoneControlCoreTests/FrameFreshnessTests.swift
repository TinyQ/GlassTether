import Testing

@testable import PhoneControlCore

@Test func freshnessRejectsStoppedMissingFutureAndInvalidFrames() {
  #expect(!FrameFreshness.isFresh(requested: false, frameTime: 10, now: 10.1))
  #expect(!FrameFreshness.isFresh(requested: true, frameTime: 0, now: 0.1))
  #expect(!FrameFreshness.isFresh(requested: true, frameTime: 11, now: 10))
  #expect(!FrameFreshness.isFresh(requested: true, frameTime: .nan, now: 10))
  #expect(!FrameFreshness.isFresh(requested: true, frameTime: 10, now: .infinity))
}

@Test func frozenVideoExpiresWithoutWaitingForAnotherFrame() {
  #expect(FrameFreshness.isFresh(requested: true, frameTime: 10, now: 10.59))
  #expect(!FrameFreshness.isFresh(requested: true, frameTime: 10, now: 10.61))
}
