import Foundation
import Testing
@testable import InspireBarCore

struct InspireQuotaTests {
    private func date(_ value: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            preconditionFailure("Bad test date: \(value)")
        }
        return date
    }

    @Test func `Monday morning belongs to the previous window until ten UTC plus eight`() {
        let boundary = self.date("2025-06-02T02:00:00Z")
        #expect(InspireQuota.window(at: boundary - 1).end == boundary)
        #expect(InspireQuota.window(at: boundary).start == boundary)
        #expect(InspireQuota.window(at: boundary).end == boundary + 7 * 86400)
    }

    @Test func `weekly projection uses net allowance and the sample timestamp`() {
        let sample = self.date("2025-06-04T02:00:00Z")
        let result = WeeklyForecast(balance: 52000, capturedAt: sample, now: sample + 300)
        #expect(result.status == .lasts)
        #expect(result.remainingAtReset == 14000)
        #expect(result.curve.first == BalanceSample(at: sample, balance: 52000))
        #expect(result.curve.last?.at == self.date("2025-06-09T02:00:00Z"))
        #expect(abs((result.pointsPerDay ?? 0) - 76) < 0.0001)
    }

    @Test func `the original CodexBar half used fixture runs out in three days`() {
        let sample = self.date("2025-06-05T02:00:00Z")
        let result = WeeklyForecast(balance: 33600, capturedAt: sample, now: sample)
        #expect(result.status == .depletes)
        #expect(result.exhaustedAt == sample + 3 * 86400)
        #expect(result.remainingAtReset == 0)
        #expect(result.curve.count == 3)
    }

    @Test func `stale samples and new windows pause the projection`() {
        let sample = self.date("2025-06-09T01:59:00Z")
        #expect(WeeklyForecast(balance: 60, capturedAt: sample, now: sample + 60).status == .stale)
        let boundary = sample + 60
        #expect(WeeklyForecast(balance: 67000, capturedAt: boundary, now: boundary).status == .warmingUp)
        #expect(WeeklyForecast(balance: 0, capturedAt: boundary, now: boundary).status == .exhausted)
    }

    @Test func `freshness follows the selected interval without crossing the weekly reset`() {
        let sample = self.date("2025-06-04T02:00:00Z")
        let now = sample + 1200
        #expect(WeeklyForecast(balance: 52000, capturedAt: sample, now: now).status == .stale)
        let atFifteenMinutes = WeeklyForecast(balance: 52000, capturedAt: sample, now: now, refreshInterval: 900)
        #expect(atFifteenMinutes.remainingAtReset == 14000)
        let reset = self.date("2025-06-09T02:00:00Z")
        let previous = WeeklyForecast(balance: 52000, capturedAt: reset - 1, now: reset, refreshInterval: 900)
        #expect(previous.status == .stale)
    }

    @Test func `billing totals and live instance rates stay separate from quota pace`() throws {
        let capturedAt = Int(self.date("2025-06-04T02:00:00Z").timeIntervalSince1970)
        let cycleStart = Int(self.date("2025-06-02T02:00:00Z").timeIntervalSince1970)
        let fixture = """
        {
          "account": "demo",
          "latest": {
            "at": \(capturedAt),
            "projects": [
              {"name": "公共科研项目", "balance": 52000, "scope": "member"},
              {"name": "Project B", "balance": 24100, "scope": "shared"}
            ],
            "active": [
              {"name": "work", "project": "Project B", "workspace": "CPU", "cards": 0, "rate": 0},
              {"name": "train", "project": "公共科研项目", "workspace": "GPU", "cards": 2, "rate": 3.75, "priority": 5},
              {"name": "demo", "project": "公共科研项目", "workspace": "GPU", "cards": 1, "rate": 0.33, "priority": 4},
              {"name": "free", "project": "公共科研项目", "workspace": "GPU", "cards": 1, "rate": 0.33, "priority": 3},
              {"name": "idle", "project": "公共科研项目", "workspace": "GPU", "cards": 1, "priority": 1}
            ],
            "missing_workspaces": []
          },
          "samples": [[\(capturedAt), 52000]],
          "days": {"2025-06-04": {"spend": {"公共科研项目": 1250, "Project B": 0}}},
          "billing": {
            "at": \(capturedAt),
            "ranges": {"30": {"公共科研项目": 62820, "Project B": 1100}},
            "cycle": {"start": \(cycleStart), "spend": {"公共科研项目": 9300}}
          }
        }
        """
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "sample.json")
        try Data(fixture.utf8).write(to: file)
        let loaded = try InspireSnapshot.load(from: file)
        let at = try #require(loaded.latest?.at)
        #expect(loaded.cycleSpend(at: at) == 9300)
        #expect(loaded.billingTotal(project: "Project B", dayCount: 30) == 1100)
        #expect(loaded.currentRate(project: InspireQuota.project, at: at) == 4.08)
        #expect(loaded.currentRate(project: "Project B", at: at) == 0)
        #expect(loaded.currentRate(project: InspireQuota.project, at: at + 901) == nil)
        #expect(loaded.currentRate(project: InspireQuota.project, at: at + 901, refreshInterval: 900) == 4.08)
        #expect(loaded.otherProjects.first?.isPersonal == false)
        #expect(loaded.weeklyForecast(at: at).remainingAtReset == 14000)
        let days = loaded.charges(project: "Project B", dayCount: 7, at: at)
        #expect(days.last?.amount == 0)
        #expect(days.dropLast().allSatisfy { $0.amount == nil })
    }
}
