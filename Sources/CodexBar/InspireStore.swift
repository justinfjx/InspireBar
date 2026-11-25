import Foundation
import InspireBarCore
import Observation

@MainActor
@Observable
final class InspireStore {
    private(set) var snapshot: InspireSnapshot?
    private(set) var now = Date()
    private(set) var isRefreshing = false
    private(set) var error: String?
    private(set) var menuOpenGeneration = 0
    private(set) var systemLowPowerEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @ObservationIgnored private var poll: Task<Void, Never>?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var powerObserver: NSObjectProtocol?
    let preferences: InspirePreferences
    private let reader: InspireReader
    private let notificationDelivery = InspireQuotaNotificationDelivery()

    var balance: Int? {
        self.snapshot?.publicProject?.balance
    }

    var statusMessage: String? {
        self.error ?? self.snapshot?.collectionError
    }

    var automaticRefreshInterval: TimeInterval? {
        BackgroundWorkPowerPolicy.automaticInterval(
            self.preferences.refreshInterval.automaticSeconds,
            lowPowerModeEnabled: self.preferences.lowPowerMode.isEnabled(systemLowPower: self.systemLowPowerEnabled))
    }

    var dataRefreshInterval: TimeInterval {
        self.automaticRefreshInterval ?? InspireQuota.pollInterval
    }

    var forecast: WeeklyForecast {
        WeeklyForecast(
            balance: self.balance,
            capturedAt: self.snapshot?.latest?.at,
            now: self.now,
            refreshInterval: self.dataRefreshInterval)
    }

    init(reader: InspireReader, preferences: InspirePreferences) {
        self.preferences = preferences
        self.reader = reader
        self.snapshot = try? InspireSnapshot.load(from: reader.snapshotURL)
    }

    func start() {
        guard !self.isRunning else { return }
        self.isRunning = true
        self.systemLowPowerEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main)
        { [weak self] _ in
            Task { @MainActor in self?.updatePowerMode() }
        }
        if self.automaticRefreshInterval != nil { self.scheduleRefresh(after: 0) }
    }

    func stop() {
        self.isRunning = false
        self.poll?.cancel()
        self.poll = nil
        if let observer = self.powerObserver {
            NotificationCenter.default.removeObserver(observer)
            self.powerObserver = nil
        }
    }

    func setRefreshInterval(_ interval: InspireRefreshInterval) {
        let previous = self.automaticRefreshInterval
        self.preferences.setRefreshInterval(interval)
        self.updateSchedule(previousInterval: previous)
    }

    func setLowPowerMode(_ mode: InspireLowPowerMode) {
        let previous = self.automaticRefreshInterval
        self.preferences.setLowPowerMode(mode)
        self.updateSchedule(previousInterval: previous)
    }

    func importPreferences(_ document: InspirePreferencesDocument) throws {
        let previous = self.automaticRefreshInterval
        try self.preferences.importDocument(document)
        self.updateSchedule(previousInterval: previous)
    }

    func currentRate(project: String) -> Double? {
        self.snapshot?.currentRate(
            project: project, at: self.now, refreshInterval: self.dataRefreshInterval)
    }

    func menuDidOpen() {
        self.updateClock()
        self.menuOpenGeneration += 1
        if self.preferences.refreshOnOpen {
            Task { await self.refresh() }
        }
    }

    func refresh() async {
        guard !self.isRefreshing else { return }
        let previous = self.snapshot
        self.poll?.cancel()
        self.poll = nil
        self.isRefreshing = true
        defer {
            self.now = Date()
            self.isRefreshing = false
            if self.isRunning {
                self.scheduleRefresh(after: self.automaticRefreshInterval)
            }
        }
        do {
            let updated = try await self.reader.refresh()
            self.snapshot = updated
            self.error = nil
            self.checkNotices(updated, previous: previous)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateClock() {
        self.now = Date()
    }

    private func updatePowerMode() {
        let previous = self.automaticRefreshInterval
        self.systemLowPowerEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.updateSchedule(previousInterval: previous)
    }

    private func updateSchedule(previousInterval: TimeInterval?) {
        let interval = self.automaticRefreshInterval
        guard self.isRunning, !self.isRefreshing, previousInterval != interval else { return }
        self.scheduleRefresh(after: previousInterval == nil && interval != nil ? 0 : interval)
    }

    private func checkNotices(_ sample: InspireSnapshot, previous: InspireSnapshot?) {
        let settings = self.preferences.alerts
        let checkTime = Date()
        guard settings.isEnabled, sample.collectionError == nil, let account = sample.account,
              let capture = sample.latest?.at, let balance = sample.publicProject?.balance,
              sample.isFresh(at: checkTime, refreshInterval: self.dataRefreshInterval)
        else { return }
        let forecast = WeeklyForecast(
            balance: balance, capturedAt: capture, now: checkTime, refreshInterval: self.dataRefreshInterval)
        guard forecast.status != .stale else { return }
        let notices = InspireQuotaNotice.evaluate(
            settings,
            balance: balance,
            previousCapture: previous?.account == account ? previous?.latest?.at : nil,
            capturedAt: capture,
            forecast: forecast)
        guard !notices.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            for notice in notices {
                await self.notificationDelivery.send(notice, account: account, balance: balance, forecast: forecast) {
                    self.preferences.alerts == settings && self.snapshot?.account == account
                        && self.snapshot?.latest?.at == capture
                }
            }
        }
    }

    private func scheduleRefresh(after delay: TimeInterval?) {
        self.poll?.cancel()
        guard let delay else {
            self.poll = nil
            return
        }
        self.poll = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            self?.poll = nil
            await self?.refresh()
        }
    }
}
