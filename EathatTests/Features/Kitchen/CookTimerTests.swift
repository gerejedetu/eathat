@testable import Eathat
import Foundation
import Testing

@Suite("Cook timer")
struct CookTimerTests {
    @Test("counts the minutes from the start, at least one", arguments: [(25, 1500.0), (0, 60), (-3, 60)])
    func span(minutes: Int, seconds: Double) {
        let start = Date(timeIntervalSince1970: 1000)
        let span = CookTimer.span(minutes: minutes, from: start)
        #expect(span.lowerBound == start)
        #expect(span.upperBound.timeIntervalSince(start) == seconds)
    }
}
