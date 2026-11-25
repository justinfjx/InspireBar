import AppKit
import InspireBarCore
import SwiftUI

@MainActor
struct PreferencesView: View {
    static let windowWidth: CGFloat = 880
    static let windowHeight: CGFloat = 620
    static let minWidth: CGFloat = 800
    static let minHeight: CGFloat = 540

    let store: InspireStore
    let selection: PreferencesSelection
    let openMenuBarSettings: () -> Void
    let updateTitle: (String) -> Void
    @State private var search = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var loginEnabled = LaunchAtLoginManager.isEnabled
    @State private var loginError: String?

    var body: some View {
        NavigationSplitView(columnVisibility: self.$columnVisibility) {
            self.sidebar
                .navigationSplitViewColumnWidth(min: 195, ideal: 260, max: 350)
        } detail: {
            self.detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(self.selection.pane.rawValue)
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        SettingsHistoryButtons(selection: self.selection)
                    }
                }
        }
        .frame(minWidth: Self.minWidth, minHeight: Self.minHeight)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.loginEnabled = LaunchAtLoginManager.isEnabled
        }
        .onChange(of: self.selection.pane) { _, pane in
            self.updateTitle(pane.rawValue)
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if #available(macOS 26.0, *) {
            self.paneList
                .searchable(text: self.$search, placement: .sidebar, prompt: "搜索设置")
        } else {
            VStack(spacing: 6) {
                TextField("搜索设置", text: self.$search)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                self.paneList
            }
        }
    }

    private var paneList: some View {
        let query = self.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let panes = SettingsPane.allCases.filter { $0.matches(query) }
        let projects = (self.store.snapshot?.latest?.projects ?? []).filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        }
        return List(selection: Binding(
            get: { Optional(self.selection.destination) },
            set: { if let destination = $0 { self.selection.selectDestination(destination) } }))
        {
            ForEach(panes, id: \.self) { pane in
                HStack(spacing: 8) {
                    if pane == .about, let icon = NSApplication.shared.applicationIconImage {
                        Image(nsImage: icon).resizable().scaledToFit()
                            .frame(width: SettingsIconChip.side, height: SettingsIconChip.side)
                            .accessibilityHidden(true)
                    } else {
                        SettingsIconChip(systemImage: pane.symbol, color: pane.color)
                    }
                    Text(pane.rawValue)
                }
                .tag(PreferencesDestination.pane(pane))
            }
            if !projects.isEmpty {
                Section("项目") {
                    ForEach(projects) { project in
                        Label(project.name, systemImage: project.name == InspireQuota.project ? "ticket" : "folder")
                            .tag(PreferencesDestination.project(project.name))
                    }
                }
            }
            if panes.isEmpty, projects.isEmpty {
                Text("没有匹配的设置").foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var detail: some View {
        switch self.selection.pane {
        case .general:
            self.general
        case .usageSpend:
            InspireUsageDashboard(store: self.store, selection: self.selection)
        case .notifications:
            InspireNotificationsPane(preferences: self.store.preferences)
        case .menuBar:
            self.menuBar
        case .menu:
            self.menu
        case .about:
            self.about
        }
    }

    private var general: some View {
        @Bindable var preferences = self.store.preferences
        return Form {
            Section("系统") {
                Toggle("开机启动", isOn: Binding(get: { self.loginEnabled }, set: self.setLogin))
                if let error = self.loginError {
                    Text(error).foregroundStyle(.orange)
                }
                if self.loginEnabled, LaunchAtLoginManager.needsApproval {
                    Button("在系统设置中允许登录启动", action: LaunchAtLoginManager.openSettings)
                }
            }
            Section("刷新") {
                SettingsMenuPicker(
                    selection: Binding(
                        get: { preferences.refreshInterval },
                        set: self.store.setRefreshInterval),
                    options: InspireRefreshInterval.allCases,
                    label: { Text("刷新间隔") },
                    optionLabel: { Text($0.title) })
                Toggle("打开菜单时刷新", isOn: $preferences.refreshOnOpen)
                SettingsMenuPicker(
                    selection: Binding(get: { preferences.lowPowerMode }, set: self.store.setLowPowerMode),
                    options: InspireLowPowerMode.allCases,
                    label: {
                        SettingsRowLabel("低功耗模式", subtitle: "自动刷新至少间隔 30 分钟；仍可手动刷新。")
                    },
                    optionLabel: { Text($0.title) })
            }
            InspirePreferencesTransferSection(store: self.store)
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    private var menuBar: some View {
        @Bindable var preferences = self.store.preferences
        return Form {
            Section("图标") {
                SettingsMenuPicker(
                    selection: $preferences.display.menuBarSize,
                    options: InspireMenuBarSize.allCases,
                    label: { Text("显示大小") },
                    optionLabel: { Text($0.title) })
            }
            Section("菜单栏布局") {
                MenuBarLayoutEditor(store: self.store)
            }
            Section("系统菜单栏") {
                LabeledContent {
                    Button("打开系统设置…", action: self.openMenuBarSettings)
                } label: {
                    SettingsRowLabel(
                        "允许在菜单栏显示",
                        subtitle: "票券未显示时，检查 macOS 和菜单栏折叠工具中的 InspireBar。")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var menu: some View {
        @Bindable var preferences = self.store.preferences
        return Form {
            Section("用量") {
                SettingsMenuPicker(
                    selection: $preferences.display.progressFill,
                    options: InspireProgressFill.allCases,
                    label: { Text("进度条显示") },
                    optionLabel: { Text($0.title) })
                Toggle("显示用量节奏", isOn: $preferences.display.showPaceMarker)
                SettingsMenuPicker(
                    selection: $preferences.display.resetDisplay,
                    options: InspireResetDisplay.allCases,
                    label: { Text("刷新时间显示") },
                    optionLabel: { Text($0.title) })
            }
            Section("内容") {
                SettingsMenuPicker(
                    selection: $preferences.display.menuOpening,
                    options: InspireMenuOpening.allCases,
                    label: { Text("打开菜单时显示") },
                    optionLabel: { Text($0.title) })
            }
            Section("账单历史") {
                SettingsMenuPicker(
                    selection: $preferences.historyDays,
                    options: InspirePreferences.historyRanges,
                    label: { Text("默认范围") },
                    optionLabel: { Text("\($0) 天") })
            }
            Section("运行实例") {
                Toggle("显示免点券实例", isOn: $preferences.showFreeInstances)
                Toggle("显示 CPU / GPU 占用率", isOn: $preferences.display.showUtilization)
            }
            ProjectNameColorsSection(store: self.store)
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    private var about: some View {
        Form {
            Section {
                LabeledContent("应用", value: "InspireBar")
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    LabeledContent("版本", value: version)
                }
                if let console = URL(string: "https://qz.sii.edu.cn/") {
                    Link("Inspire 控制台", destination: console)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            self.loginError = nil
        } catch {
            self.loginError = "请在系统设置的登录项中管理 InspireBar。"
        }
        self.loginEnabled = LaunchAtLoginManager.isEnabled
    }
}

@MainActor
private struct SettingsHistoryButtons: View {
    let selection: PreferencesSelection

    var body: some View {
        ControlGroup {
            Button(action: self.selection.goBack) {
                Label("后退", systemImage: "chevron.backward")
            }
            .disabled(!self.selection.canGoBack)
            .keyboardShortcut("[", modifiers: .command)

            Button(action: self.selection.goForward) {
                Label("前进", systemImage: "chevron.forward")
            }
            .disabled(!self.selection.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
        }
        .controlGroupStyle(.navigation)
        .labelStyle(.iconOnly)
        .fixedSize()
    }
}
