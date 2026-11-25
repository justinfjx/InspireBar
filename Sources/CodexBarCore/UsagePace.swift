import Foundation

/// CodexBar's linear weekly pace, applied to a single Inspire quota window.
package struct UsagePace: Equatable, Sendable {
    package let expectedUsedPercent: Double
    package let actualUsedPercent: Double
    package let projectedRemainingUsage: Double
    package let usedPercentPerDay: Double
    package let etaSeconds: TimeInterval?

    package static func weekly(
        usedPercent: Double,
        start: Date,
        reset: Date,
        now: Date)
        -> UsagePace?
    {
        let duration = reset.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        let timeUntilReset = reset.timeIntervalSince(now)
        guard duration > 0, elapsed >= duration * 0.03, timeUntilReset > 0, usedPercent.isFinite else {
            return nil
        }
        let actual = usedPercent.clamped(to: 0...100)
        let rate = actual / elapsed
        let etaSeconds = rate > 0 ? (100 - actual) / rate : nil
        return UsagePace(
            expectedUsedPercent: 100 * elapsed / duration,
            actualUsedPercent: actual,
            projectedRemainingUsage: rate * timeUntilReset,
            usedPercentPerDay: rate * 86400,
            etaSeconds: etaSeconds.flatMap { $0 <= timeUntilReset ? $0 : nil })
    }
}
