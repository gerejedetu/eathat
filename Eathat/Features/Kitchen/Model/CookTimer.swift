import Foundation

/// The recipe timer's countdown.
enum CookTimer {
    /// From `start` to `minutes` later; at least a minute, so the range is never empty or backwards.
    static func span(minutes: Int, from start: Date = .now) -> ClosedRange<Date> {
        start...start.addingTimeInterval(TimeInterval(max(minutes, 1) * 60))
    }
}
