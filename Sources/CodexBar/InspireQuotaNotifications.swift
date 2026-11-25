import Foundation
import InspireBarCore
import OSLog
import UserNotifications

enum InspireQuotaNotice: String, Sendable {
    case lowBalance, projectedDepletion, newCycle

    static func evaluate(
        _ settings: InspireQuotaAlerts,
        balance: Int,
        previousCapture: Date?,
        capturedAt: Date,
        forecast: WeeklyForecast)
        -> [Self]
    {
        var notices: [Self] = []
        let reset = forecast.window.start
        if settings.newCycle, let previousCapture, previousCapture < reset,
           capturedAt >= reset, capturedAt.timeIntervalSince(reset) <= 3600
        {
            notices.append(.newCycle)
        }
        let percent = 100 * Double(balance) / Double(InspireQuota.allowance)
        if settings.lowBalance, percent <= Double(settings.threshold) {
            notices.append(.lowBalance)
        } else if settings.projectedDepletion, forecast.status == .depletes {
            notices.append(.projectedDepletion)
        }
        return notices
    }

    func message(balance: Int, forecast: WeeklyForecast) -> (title: String, body: String) {
        let points = InspireQuota.points(balance)
        switch self {
        case .lowBalance:
            return ("公共科研点券余额提醒", "剩余 \(points) 点券。")
        case .projectedDepletion:
            let date = forecast.exhaustedAt.map { InspireQuota.dateText($0, format: "MM/dd HH:mm") } ?? "本周期内"
            return ("预计在刷新前用完点券", "按本周消耗节奏，预计 \(date) 耗尽。")
        case .newCycle:
            return ("公共科研点券进入新周期", "同步到的余额为 \(points) 点券。")
        }
    }
}

/// Presents only user-enabled notices. Permission is requested from Settings, never from polling.
@MainActor
final class InspireQuotaNotificationDelivery: NSObject, UNUserNotificationCenterDelegate {
    private let defaults: UserDefaults
    private let deliveredKey = "deliveredQuotaNotices"
    private var sending: Set<String> = []
    private let logger = Logger(subsystem: "io.github.justinfjx.inspirebar", category: "notifications")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions
    {
        [.banner, .list, .sound]
    }

    func send(
        _ notice: InspireQuotaNotice,
        account: String,
        balance: Int,
        forecast: WeeklyForecast,
        isCurrent: () -> Bool)
        async
    {
        let week = Int(forecast.window.start.timeIntervalSince1970)
        let id = "inspirebar-\(account)-\(week)-\(notice.rawValue)"
        guard isCurrent(), !self.delivered.contains(id), self.sending.insert(id).inserted else { return }
        defer { self.sending.remove(id) }

        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard isCurrent(), status == .authorized || status == .provisional else { return }
        center.delegate = self
        let message = notice.message(balance: balance, forecast: forecast)
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        do {
            try await center.add(request)
            self.defaults.set(Array((self.delivered + [id]).suffix(40)), forKey: self.deliveredKey)
        } catch {
            self.logger
                .warning("Unable to deliver a quota notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var delivered: [String] {
        self.defaults.stringArray(forKey: self.deliveredKey) ?? []
    }
}
