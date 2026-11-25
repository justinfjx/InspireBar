import Foundation

enum InspireLowPowerMode: String, Codable, CaseIterable {
    case off, automatic, on

    var title: String {
        switch self {
        case .off: "关闭"
        case .automatic: "自动"
        case .on: "开启"
        }
    }

    func isEnabled(systemLowPower: Bool) -> Bool {
        self == .on || (self == .automatic && systemLowPower)
    }
}

enum InspireProgressFill: String, Codable, CaseIterable {
    case remaining, used

    var title: String {
        self == .remaining ? "剩余" : "已用"
    }

    func value(remaining: Double) -> Double {
        self == .remaining ? remaining : 100 - remaining
    }
}

enum InspireResetDisplay: String, Codable, CaseIterable {
    case absolute, countdown, both

    var title: String {
        switch self {
        case .absolute: "刷新时间"
        case .countdown: "倒计时"
        case .both: "同时显示"
        }
    }

    func text(absolute: String, countdown: String) -> String {
        switch self {
        case .absolute: "\(absolute) 刷新"
        case .countdown: "\(countdown)后刷新"
        case .both: "\(absolute) 刷新（\(countdown)后）"
        }
    }
}

enum InspireMenuTab: String, Codable, CaseIterable {
    case usage, trend, projects

    var title: String {
        switch self {
        case .usage: "点券"
        case .trend: "趋势"
        case .projects: "项目"
        }
    }
}

enum InspireMenuOpening: String, Codable, CaseIterable {
    case lastUsed, usage, trend, projects

    var tab: InspireMenuTab? {
        InspireMenuTab(rawValue: self.rawValue)
    }

    var title: String {
        self.tab?.title ?? "记住上次"
    }
}

enum InspireMenuBarSize: String, Codable, CaseIterable {
    case small, regular, large

    var title: String {
        switch self {
        case .small: "小"
        case .regular: "标准"
        case .large: "大"
        }
    }

    func fontSize(stacked: Bool) -> CGFloat {
        switch self {
        case .small: stacked ? 8 : 11
        case .regular: stacked ? 9 : 13
        case .large: stacked ? 10 : 14
        }
    }
}

struct InspireDisplayOptions: Codable, Equatable {
    var menuBarSize = InspireMenuBarSize.regular
    var progressFill = InspireProgressFill.remaining
    var showPaceMarker = true
    var resetDisplay = InspireResetDisplay.absolute
    var menuOpening = InspireMenuOpening.lastUsed
    var showUtilization = true
}
