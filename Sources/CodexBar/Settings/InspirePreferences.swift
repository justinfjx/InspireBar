import Foundation
import InspireBarCore
import Observation

enum InspireRefreshInterval: Int, Codable, CaseIterable {
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case manual = 0

    var automaticSeconds: TimeInterval? {
        self == .manual ? nil : TimeInterval(self.rawValue * 60)
    }

    var title: String {
        self == .manual ? "手动" : "\(self.rawValue) 分钟"
    }
}

struct InspireQuotaAlerts: Codable, Equatable {
    static let thresholds = [10, 20, 30, 50]

    var lowBalance = false
    var threshold = 20
    var projectedDepletion = false
    var newCycle = false

    var isEnabled: Bool {
        self.lowBalance || self.projectedDepletion || self.newCycle
    }
}

struct InspirePreferencesDocument: Codable, Equatable {
    static let currentVersion = 1

    var version = Self.currentVersion
    var refreshInterval: InspireRefreshInterval
    var refreshOnOpen: Bool
    var lowPowerMode: InspireLowPowerMode
    var menuBarLayout: MenuBarLayout
    var historyDays: Int
    var showFreeInstances: Bool
    var display: InspireDisplayOptions
    var alerts: InspireQuotaAlerts
}

@MainActor
@Observable
final class InspirePreferences {
    static let historyRanges = [7, 15, 30]

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var refreshInterval: InspireRefreshInterval {
        didSet { self.defaults.set(self.refreshInterval.rawValue, forKey: "refreshIntervalMinutes") }
    }

    private(set) var lowPowerMode: InspireLowPowerMode {
        didSet { self.defaults.set(self.lowPowerMode.rawValue, forKey: "lowPowerMode") }
    }

    var refreshOnOpen: Bool {
        didSet { self.defaults.set(self.refreshOnOpen, forKey: "refreshOnMenuOpen") }
    }

    var menuBarLayout: MenuBarLayout {
        didSet {
            if let data = try? JSONEncoder().encode(self.menuBarLayout) {
                self.defaults.set(data, forKey: "menuBarLayoutV1")
            }
        }
    }

    var historyDays: Int {
        didSet { self.defaults.set(self.historyDays, forKey: "defaultHistoryDays") }
    }

    var showFreeInstances: Bool {
        didSet { self.defaults.set(self.showFreeInstances, forKey: "showFreeInstances") }
    }

    var display: InspireDisplayOptions {
        didSet { self.defaults.set(try? JSONEncoder().encode(self.display), forKey: "displayOptionsV1") }
    }

    var alerts: InspireQuotaAlerts {
        didSet { self.defaults.set(try? JSONEncoder().encode(self.alerts), forKey: "quotaAlertsV1") }
    }

    var lastMenuTab: InspireMenuTab {
        didSet { self.defaults.set(self.lastMenuTab.rawValue, forKey: "lastMenuTab") }
    }

    private var projectNameColors: [String: [String: ProjectNameColor]] {
        didSet { self.defaults.set(try? JSONEncoder().encode(self.projectNameColors), forKey: "projectNameColorsV1") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.refreshInterval = (defaults.object(forKey: "refreshIntervalMinutes") as? Int)
            .flatMap(InspireRefreshInterval.init(rawValue:)) ?? .fiveMinutes
        self.lowPowerMode = defaults.string(forKey: "lowPowerMode").flatMap(InspireLowPowerMode.init(rawValue:)) ?? .off
        self.refreshOnOpen = defaults.bool(forKey: "refreshOnMenuOpen")
        let previousLayout: MenuBarLayout = defaults.string(forKey: "menuBarDisplayMode") == "iconOnly"
            ? .iconOnly : .defaultLayout
        self.menuBarLayout = defaults.data(forKey: "menuBarLayoutV1")
            .flatMap { try? JSONDecoder().decode(MenuBarLayout.self, from: $0) } ?? previousLayout
        let days = defaults.integer(forKey: "defaultHistoryDays")
        self.historyDays = Self.historyRanges.contains(days) ? days : 30
        self.showFreeInstances = defaults.object(forKey: "showFreeInstances") as? Bool ?? true
        self.display = defaults.data(forKey: "displayOptionsV1")
            .flatMap { try? JSONDecoder().decode(InspireDisplayOptions.self, from: $0) } ?? InspireDisplayOptions()
        self.alerts = defaults.data(forKey: "quotaAlertsV1")
            .flatMap { try? JSONDecoder().decode(InspireQuotaAlerts.self, from: $0) } ?? InspireQuotaAlerts()
        self.lastMenuTab = defaults.string(forKey: "lastMenuTab").flatMap(InspireMenuTab.init(rawValue:)) ?? .usage
        self.projectNameColors = defaults.data(forKey: "projectNameColorsV1").flatMap {
            try? JSONDecoder().decode([String: [String: ProjectNameColor]].self, from: $0)
        } ?? [:]
    }

    func projectNameColor(_ project: String, account: String?) -> ProjectNameColor {
        guard let account else { return .black }
        return self.projectNameColors[account]?[project] ?? .black
    }

    func setProjectNameColor(_ color: ProjectNameColor, project: String, account: String) {
        guard color != self.projectNameColor(project, account: account) else { return }
        var colors = self.projectNameColors[account] ?? [:]
        colors[project] = color == .black ? nil : color
        self.projectNameColors[account] = colors.isEmpty ? nil : colors
    }

    func setRefreshInterval(_ interval: InspireRefreshInterval) {
        self.refreshInterval = interval
    }

    func setLowPowerMode(_ mode: InspireLowPowerMode) {
        self.lowPowerMode = mode
    }

    func exportDocument() -> InspirePreferencesDocument {
        InspirePreferencesDocument(
            refreshInterval: self.refreshInterval,
            refreshOnOpen: self.refreshOnOpen,
            lowPowerMode: self.lowPowerMode,
            menuBarLayout: self.menuBarLayout,
            historyDays: self.historyDays,
            showFreeInstances: self.showFreeInstances,
            display: self.display,
            alerts: self.alerts)
    }

    func importDocument(_ document: InspirePreferencesDocument) throws {
        guard document.version == InspirePreferencesDocument.currentVersion,
              Self.historyRanges.contains(document.historyDays),
              InspireQuotaAlerts.thresholds.contains(document.alerts.threshold)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.refreshInterval = document.refreshInterval
        self.refreshOnOpen = document.refreshOnOpen
        self.lowPowerMode = document.lowPowerMode
        self.menuBarLayout = document.menuBarLayout
        self.historyDays = document.historyDays
        self.showFreeInstances = document.showFreeInstances
        self.display = document.display
        self.alerts = document.alerts
    }
}
