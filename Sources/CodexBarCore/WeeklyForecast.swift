import Foundation

package struct WeeklyForecast: Equatable, Sendable {
    package enum Status: Equatable, Sendable {
        case waiting, stale, warmingUp, lasts, depletes, exhausted
    }

    package let window: DateInterval
    package let status: Status
    package let pace: UsagePace?
    package let remainingAtReset: Int?
    package let exhaustedAt: Date?
    package let curve: [BalanceSample]

    package var pointsPerDay: Double? {
        self.pace.map { $0.usedPercentPerDay * Double(InspireQuota.allowance) / 10000 }
    }

    package init(
        balance: Int?,
        capturedAt: Date?,
        now: Date,
        refreshInterval: TimeInterval = InspireQuota.pollInterval)
    {
        let window = InspireQuota.window(at: now)
        self.window = window
        guard let balance, let capturedAt else {
            self.status = .waiting
            self.pace = nil
            self.remainingAtReset = nil
            self.exhaustedAt = nil
            self.curve = []
            return
        }
        guard capturedAt >= window.start, InspireQuota.isFresh(capturedAt, at: now, refreshInterval: refreshInterval)
        else {
            self.status = .stale
            self.pace = nil
            self.remainingAtReset = nil
            self.exhaustedAt = nil
            self.curve = []
            return
        }

        let allowance = Double(InspireQuota.allowance)
        let usedPercent = 100 * (allowance - Double(balance)) / allowance
        let pace = UsagePace.weekly(usedPercent: usedPercent, start: window.start, reset: window.end, now: capturedAt)
        self.pace = pace
        if balance <= 0 {
            self.status = .exhausted
            self.remainingAtReset = 0
            self.exhaustedAt = capturedAt
            self.curve = [BalanceSample(at: capturedAt, balance: 0), BalanceSample(at: window.end, balance: 0)]
        } else if let pace {
            let remaining = max(0, Int((Double(balance) - pace.projectedRemainingUsage * allowance / 100).rounded()))
            let exhaustedAt = pace.etaSeconds.map { min(window.end, capturedAt + $0.rounded(.up)) }
            self.status = exhaustedAt == nil ? .lasts : .depletes
            self.remainingAtReset = remaining
            self.exhaustedAt = exhaustedAt
            var curve = [BalanceSample(at: capturedAt, balance: balance)]
            if let exhaustedAt, exhaustedAt < window.end {
                curve.append(BalanceSample(at: exhaustedAt, balance: 0))
            }
            self.curve = curve + [BalanceSample(at: window.end, balance: remaining)]
        } else {
            self.status = .warmingUp
            self.remainingAtReset = nil
            self.exhaustedAt = nil
            self.curve = []
        }
    }
}

extension InspireSnapshot {
    package func weeklyForecast(at now: Date) -> WeeklyForecast {
        WeeklyForecast(balance: self.publicProject?.balance, capturedAt: self.latest?.at, now: now)
    }

    package func balanceHistory(in window: DateInterval) -> [BalanceSample] {
        (self.samples ?? []).filter { $0.at >= window.start && $0.at < window.end }.sorted { $0.at < $1.at }
    }

    package struct ResetObservation: Identifiable, Sendable {
        package let date: Date
        package let before: BalanceSample?
        package let after: BalanceSample?
        package var id: Date {
            self.date
        }
    }

    package func resetHistory(
        at now: Date,
        refreshInterval: TimeInterval = InspireQuota.pollInterval)
        -> [ResetObservation]
    {
        let start = InspireQuota.window(at: now).start
        let samples = self.samples ?? []
        let tolerance = refreshInterval * 2
        return (0..<4).compactMap { offset in
            let date = start - Double(offset) * 7 * InspireQuota.day
            let before = samples.last { $0.at < date && $0.at >= date - tolerance }
            let after = samples.first { $0.at >= date && $0.at <= date + tolerance }
            guard before != nil || after != nil else { return nil }
            return ResetObservation(date: date, before: before, after: after)
        }
    }
}
