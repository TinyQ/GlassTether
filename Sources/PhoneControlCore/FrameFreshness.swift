import Foundation

/// Monotonic capture timestamps only; invalid or future timestamps fail closed.
public enum FrameFreshness {
  public static func isFresh(requested: Bool, frameTime: TimeInterval, now: TimeInterval) -> Bool {
    requested && frameTime.isFinite && now.isFinite && frameTime > 0
      && now >= frameTime && now - frameTime < 0.6
  }
}
