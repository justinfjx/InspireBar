import Foundation
import Observation
import SwiftUI

enum SettingsPane: String, CaseIterable {
    case general = "通用"
    case usageSpend = "用量与支出"
    case notifications = "通知"
    case menuBar = "菜单栏"
    case menu = "菜单"
    case about = "关于"

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .usageSpend: "chart.bar.fill"
        case .notifications: "bell.badge.fill"
        case .menuBar: "menubar.rectangle"
        case .menu: "filemenu.and.selection"
        case .about: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .usageSpend: .green
        case .notifications: .red
        case .menuBar: .blue
        case .menu: .teal
        case .about: .green
        }
    }

    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let searchText = switch self {
        case .general: "通用 开机启动 刷新间隔 同步 登录 低功耗 导入 导出"
        case .usageSpend: "用量与支出 趋势 历史 账单 项目 CSV"
        case .notifications: "通知 余额提醒 阈值 预计耗尽 点券刷新"
        case .menuBar: "菜单栏 布局 预设 预览 图标 点券 余额 显示 行数 单行 双行 倒计时 预计余量 大小"
        case .menu: "菜单 账单历史 默认范围 免点券实例 占用率 CPU GPU 进度条 节奏 刷新时间 项目名称颜色"
        case .about: "关于 InspireBar 版本"
        }
        return searchText.localizedCaseInsensitiveContains(query)
    }
}

enum PreferencesDestination: Hashable {
    case pane(SettingsPane)
    case project(String)

    var pane: SettingsPane {
        switch self {
        case let .pane(pane): pane
        case .project: .usageSpend
        }
    }
}

@MainActor
@Observable
final class PreferencesSelection {
    private(set) var destination = PreferencesDestination.pane(.general)
    private var backStack: [PreferencesDestination] = []
    private var forwardStack: [PreferencesDestination] = []

    var pane: SettingsPane {
        self.destination.pane
    }

    var canGoBack: Bool {
        !self.backStack.isEmpty
    }

    var canGoForward: Bool {
        !self.forwardStack.isEmpty
    }

    var projectName: String? {
        if case let .project(name) = self.destination {
            name
        } else { nil }
    }

    func select(_ pane: SettingsPane) {
        self.selectDestination(.pane(pane))
    }

    func selectDestination(_ destination: PreferencesDestination) {
        guard destination != self.destination else { return }
        self.backStack.append(self.destination)
        self.forwardStack.removeAll()
        self.destination = destination
    }

    func goBack() {
        guard let previous = self.backStack.popLast() else { return }
        self.forwardStack.append(self.destination)
        self.destination = previous
    }

    func goForward() {
        guard let next = self.forwardStack.popLast() else { return }
        self.backStack.append(self.destination)
        self.destination = next
    }
}
