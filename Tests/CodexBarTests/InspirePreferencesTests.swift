import Foundation
import InspireBarCore
import SwiftUI
import Testing
@testable import InspireBar

@MainActor
struct InspirePreferencesTests {
    @Test func `portable preferences restore appearance and refresh without account state`() throws {
        let suite = "InspireBar.InspirePreferencesTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = InspirePreferences(defaults: defaults)
        #expect(preferences.refreshInterval == .fiveMinutes)
        preferences.menuBarLayout = .defaultLayout.withTwoLines()
        preferences.display.progressFill = .used
        preferences.display.menuBarSize = .large
        preferences.alerts.lowBalance = true
        preferences.lastMenuTab = .projects
        preferences.setRefreshInterval(.manual)

        let document = preferences.exportDocument()
        let data = try JSONEncoder().encode(document)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == [
            "version", "refreshInterval", "refreshOnOpen", "lowPowerMode", "menuBarLayout",
            "historyDays", "showFreeInstances", "display", "alerts",
        ])
        #expect(InspirePreferences(defaults: defaults).refreshInterval == .manual)
        preferences.setRefreshInterval(.fifteenMinutes)
        preferences.display.progressFill = .remaining
        preferences.lastMenuTab = .trend
        try preferences.importDocument(JSONDecoder().decode(InspirePreferencesDocument.self, from: data))
        #expect(preferences.exportDocument() == document)
        #expect(preferences.lastMenuTab == .trend)

        var invalid = document
        invalid.historyDays = 700
        invalid.refreshInterval = .oneMinute
        #expect(throws: CocoaError.self) { try preferences.importDocument(invalid) }
        #expect(preferences.exportDocument() == document)
    }

    @Test func `the CodexBar power floor applies to polling but not manual mode`() {
        let automatic = InspireLowPowerMode.automatic
        let fiveMinutes = InspireRefreshInterval.fiveMinutes.automaticSeconds
        #expect(BackgroundWorkPowerPolicy.automaticInterval(
            fiveMinutes, lowPowerModeEnabled: automatic.isEnabled(systemLowPower: false)) == 300)
        #expect(BackgroundWorkPowerPolicy.automaticInterval(
            fiveMinutes, lowPowerModeEnabled: automatic.isEnabled(systemLowPower: true)) == 1800)
        #expect(BackgroundWorkPowerPolicy.automaticInterval(
            InspireRefreshInterval.manual.automaticSeconds, lowPowerModeEnabled: true) == nil)
    }

    @Test func `the color picker saves project colors locally and resets them to black`() throws {
        let suite = "InspireBar.InspirePreferencesTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = InspirePreferences(defaults: defaults)
        let originalDocument = preferences.exportDocument()
        let row = ProjectNameColorRow(project: "Demo A", account: "account-a", preferences: preferences)
        let violet = ProjectNameColor(red: 145, green: 62, blue: 171)
        let blue = ProjectNameColor(red: 0, green: 100, blue: 180)

        #expect(ProjectNameColor.selected(row.colorSelection.wrappedValue) == .black)
        row.colorSelection.wrappedValue = violet.swatch
        preferences.setProjectNameColor(blue, project: "Demo B", account: "account-a")
        #expect(preferences.projectNameColor("Demo A", account: "account-a") == violet)
        #expect(preferences.projectNameColor("Demo A", account: "account-b") == .black)
        #expect(preferences.projectNameColor("Demo B", account: "account-a") == blue)
        #expect(preferences.exportDocument() == originalDocument)
        #expect(InspirePreferences(defaults: defaults).projectNameColor("Demo A", account: "account-a") == violet)

        row.colorSelection.wrappedValue = ProjectNameColor.black.swatch
        let reloaded = InspirePreferences(defaults: defaults)
        #expect(reloaded.projectNameColor("Demo A", account: "account-a") == .black)
        #expect(reloaded.projectNameColor("Demo B", account: "account-a") == blue)
        #expect(SettingsPane.menu.matches("项目名称颜色"))
    }

    @Test func `sidebar project shortcuts keep the selected account project in navigation history`() {
        let selection = PreferencesSelection()
        selection.selectDestination(.project("Demo"))
        #expect(selection.pane == .usageSpend)
        #expect(selection.projectName == "Demo")
        selection.select(.notifications)
        selection.goBack()
        #expect(selection.projectName == "Demo")
        selection.goForward()
        #expect(selection.pane == .notifications)
    }

    @Test func `quota alerts follow the weekly forecast and avoid duplicate warning types`() {
        let previous = Date(timeIntervalSince1970: 1_749_002_400) // 2025-06-04 02:00 UTC
        let window = InspireQuota.window(at: previous)
        let refreshed = window.end + 300
        let fresh = WeeklyForecast(balance: 67200, capturedAt: refreshed, now: refreshed)
        var alerts = InspireQuotaAlerts()
        alerts.newCycle = true
        #expect(InspireQuotaNotice.evaluate(
            alerts, balance: 67200, previousCapture: previous, capturedAt: refreshed, forecast: fresh) == [.newCycle])
        #expect(InspireQuotaNotice.evaluate(
            alerts, balance: 67200, previousCapture: refreshed, capturedAt: refreshed, forecast: fresh).isEmpty)

        let forecast = WeeklyForecast(balance: 10000, capturedAt: previous, now: previous)
        alerts.projectedDepletion = true
        #expect(InspireQuotaNotice.evaluate(
            alerts, balance: 10000, previousCapture: nil, capturedAt: previous, forecast: forecast)
            == [.projectedDepletion])
        alerts.lowBalance = true
        #expect(InspireQuotaNotice.evaluate(
            alerts, balance: 10000, previousCapture: nil, capturedAt: previous, forecast: forecast) == [.lowBalance])
    }
}
