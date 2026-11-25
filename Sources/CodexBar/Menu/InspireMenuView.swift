import AppKit
import InspireBarCore
import SwiftUI

struct InspireMenuView: View {
    let store: InspireStore
    let openSettings: () -> Void
    let openUsageDashboard: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: InspireMenuTab
    @State private var dayCount: Int
    @State private var project: String?
    @State private var freeInstancesExpanded = true

    init(store: InspireStore, openSettings: @escaping () -> Void, openUsageDashboard: @escaping () -> Void) {
        self.store = store
        self.openSettings = openSettings
        self.openUsageDashboard = openUsageDashboard
        self._tab = State(initialValue: store.preferences.display.menuOpening.tab ?? store.preferences.lastMenuTab)
        self._dayCount = State(initialValue: store.preferences.historyDays)
    }

    var body: some View {
        VStack(spacing: 0) {
            self.header
            Picker("用量视图", selection: self.$tab) {
                ForEach(InspireMenuTab.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
            .padding(.bottom, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let message = self.store.statusMessage {
                        Text(message).font(.footnote).foregroundStyle(.orange)
                    }
                    if let snapshot = self.store.snapshot, snapshot.latest != nil {
                        self.content(snapshot)
                    } else if self.store.statusMessage == nil {
                        let waiting = self.store.isRefreshing || self.store.automaticRefreshInterval != nil
                        Text(waiting ? "正在读取 Inspire 点券…" : "点按刷新，读取 Inspire 点券。")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
                .padding(.vertical, 12)
            }
            Divider()
            self.footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: self.store.preferences.historyDays) { _, days in
            self.dayCount = days
        }
        .onChange(of: self.tab) { _, tab in self.store.preferences.lastMenuTab = tab }
        .onChange(of: self.store.menuOpenGeneration) { _, _ in
            self.tab = self.store.preferences.display.menuOpening.tab ?? self.store.preferences.lastMenuTab
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: UsageMenuCardLayout.headerLineSpacing) {
                UsageMenuCardTitleView(title: "InspireBar")
                if let at = self.store.snapshot?.latest?.at {
                    let time = InspireQuota.dateText(at, format: "HH:mm")
                    Text(self.store.isRefreshing ? "正在同步" : "上次同步 \(time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task { await self.store.refresh() }
            } label: {
                if self.store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .disabled(self.store.isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
            .frame(width: 24, height: 24)
            .accessibilityLabel("刷新")
            .help("刷新 Inspire 点券")
        }
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func content(_ snapshot: InspireSnapshot) -> some View {
        switch self.tab {
        case .usage:
            self.quotaCard(snapshot)
            self.instances(snapshot, project: InspireQuota.project)
        case .trend:
            self.trend(snapshot)
            self.history(snapshot, project: InspireQuota.project)
        case .projects:
            self.projects(snapshot)
        }
    }

    private func quotaCard(_ snapshot: InspireSnapshot) -> some View {
        let forecast = self.store.forecast
        let balance = self.store.balance
        let display = self.store.preferences.display
        return self.card {
            UsageMenuCardTitleView(title: InspireQuota.project)
            MetricRow(title: "个人可用点券", value: InspireQuota.points(balance), emphasized: true)
            if let balance {
                let remaining = Double(balance) / Double(InspireQuota.allowance) * 100
                let percent = display.progressFill.value(remaining: remaining)
                UsageProgressBar(
                    percent: percent,
                    pacePercent: display.showPaceMarker
                        ? forecast.pace.map { display.progressFill.value(remaining: 100 - $0.expectedUsedPercent) }
                        : nil,
                    stale: forecast.status == .stale,
                    fill: display.progressFill)
                self.quotaCaption(percent: percent, display: display, end: forecast.window.end)
            }
            Divider()
            MetricRow(title: "本周期账单", value: InspireQuota.points(snapshot.cycleSpend(at: self.store.now)))
            MetricRow(title: "当前计费速率", value: self.rate(self.store.currentRate(project: InspireQuota.project)))
            MetricRow(title: "刷新前预计剩余", value: InspireQuota.points(forecast.remainingAtReset))
            MetricRow(title: "预计耗尽", value: self.depletion(forecast))
        }
    }

    private func quotaCaption(percent: Double, display: InspireDisplayOptions, end: Date) -> some View {
        let amount = Int(min(100, max(0, percent)).rounded())
        let absolute = InspireQuota.dateText(end, format: "MM/dd HH:mm")
        return TimelineView(.periodic(from: self.store.now, by: 60)) { context in
            let countdown = InspireQuota.countdown(until: end, at: context.date)
            let reset = display.resetDisplay.text(absolute: absolute, countdown: countdown)
            Text("\(amount)% \(display.progressFill.title) · \(reset)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func history(_ snapshot: InspireSnapshot, project: String) -> some View {
        self.card {
            HStack {
                UsageMenuCardTitleView(title: "点券消耗")
                Spacer()
                Picker("账单范围", selection: self.$dayCount) {
                    ForEach(InspirePreferences.historyRanges, id: \.self) { Text("\($0) 天").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 151)
            }
            CreditsHistoryChartMenuView(
                days: snapshot.charges(project: project, dayCount: self.dayCount, at: self.store.now),
                total: snapshot.billingTotal(project: project, dayCount: self.dayCount))
                .id("\(project)/\(self.dayCount)")
            if let message = snapshot.billingError {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func trend(_ snapshot: InspireSnapshot) -> some View {
        let forecast = self.store.forecast
        return self.card {
            UsageMenuCardTitleView(title: "余额与预测")
            QuotaBurndownChartMenuView(actual: snapshot.balanceHistory(in: forecast.window), forecast: forecast)
            MetricRow(title: "刷新前预计剩余", value: InspireQuota.points(forecast.remainingAtReset))
            MetricRow(title: "预计耗尽", value: self.depletion(forecast))
            let resets = snapshot.resetHistory(at: self.store.now, refreshInterval: self.store.dataRefreshInterval)
            if !resets.isEmpty {
                Divider()
                ForEach(resets) { reset in
                    let before = InspireQuota.points(reset.before?.balance)
                    let after = InspireQuota.points(reset.after?.balance)
                    MetricRow(
                        title: InspireQuota.dateText(reset.date, format: "MM/dd HH:mm"),
                        value: "\(before) → \(after)")
                }
            }
        }
    }

    @ViewBuilder
    private func projects(_ snapshot: InspireSnapshot) -> some View {
        let others = snapshot.otherProjects
        if let selected = others.first(where: { $0.name == self.project }) ?? others.first {
            self.card {
                Picker("项目", selection: Binding(
                    get: { selected.name }, set: { self.project = $0 }))
                {
                    ForEach(others) { Text($0.name).tag($0.name) }
                }
                MetricRow(
                    title: selected.isPersonal ? "个人可用点券" : "项目共享余额",
                    value: InspireQuota.points(selected.balance),
                    emphasized: true)
                MetricRow(
                    title: "近 30 天已扣",
                    value: InspireQuota.points(snapshot.billingTotal(project: selected.name, dayCount: 30)))
                MetricRow(title: "当前计费速率", value: self.rate(self.store.currentRate(project: selected.name)))
            }
            self.history(snapshot, project: selected.name)
            self.instances(snapshot, project: selected.name)
        } else {
            Text("当前账号没有其他项目").foregroundStyle(.secondary)
        }
    }

    private func instances(_ snapshot: InspireSnapshot, project: String) -> some View {
        let tasks = snapshot.instanceList(project: project)
        let paid = tasks.filter { $0.billingRate != 0 }
        let free = tasks.filter { $0.billingRate == 0 }
        let showUtilization = self.store.preferences.display.showUtilization
            && snapshot.isFresh(at: self.store.now, refreshInterval: self.store.dataRefreshInterval)
        let projectColor = self.store.preferences.projectNameColor(project, account: snapshot.account)
        return self.card {
            UsageMenuCardTitleView(title: "运行实例")
            if paid.isEmpty {
                let complete = snapshot.latest?.missingWorkspaces.isEmpty == true
                Text(complete ? "当前没有计费实例" : "部分工作空间尚未读取")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                self.instanceRows(paid, projectColor: projectColor, showUtilization: showUtilization)
            }
            if self.store.preferences.showFreeInstances, !free.isEmpty {
                Divider().padding(.vertical, 2)
                Button {
                    self.freeInstancesExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: self.freeInstancesExpanded ? "chevron.down" : "chevron.right")
                            .imageScale(.small)
                        Text("免点券实例 · \(free.count)")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
                .accessibilityValue(self.freeInstancesExpanded ? "已展开" : "已折叠")
                if self.freeInstancesExpanded {
                    self.instanceRows(free, projectColor: projectColor, showUtilization: showUtilization)
                }
            }
        }
    }

    private func instanceRows(
        _ tasks: [InspireInstance],
        projectColor: ProjectNameColor,
        showUtilization: Bool)
        -> some View
    {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(tasks) { task in
                if task.id != tasks.first?.id {
                    Divider().padding(.vertical, 6)
                }
                self.instanceRow(task, projectColor: projectColor, showUtilization: showUtilization)
            }
        }
    }

    private func instanceRow(
        _ task: InspireInstance,
        projectColor: ProjectNameColor,
        showUtilization: Bool)
        -> some View
    {
        let readings = showUtilization ? task.utilization : []
        let project = Text(task.project).foregroundStyle(projectColor.textColor(in: self.colorScheme))
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.body.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 2) {
                    ViewThatFits(in: .horizontal) {
                        Text("\(task.cardLabel) · \(task.priorityLabel)")
                            .fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.cardLabel)
                            Text(task.priorityLabel)
                        }
                    }
                    Text("\(project) · \(task.workspace)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(self.rate(task.billingRate))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                ForEach(readings) { self.utilizationMeter($0) }
            }
            .frame(width: readings.isEmpty ? nil : 144, alignment: .trailing)
        }
        .accessibilityElement(children: .contain)
    }

    private func utilizationMeter(_ reading: InspireInstance.Utilization) -> some View {
        let color = MenuHighlightStyle.utilizationTint(reading.band, scheme: self.colorScheme)
        return HStack(spacing: 6) {
            Text(reading.id.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(MenuHighlightStyle.progressTrack)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * reading.fraction)
                }
            }
            .frame(height: 6)
            Text(reading.percentage)
                .font(.caption)
                .monospacedDigit()
                .frame(width: 39, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reading.id.rawValue) 占用率")
        .accessibilityValue(reading.percentage)
    }

    private var footer: some View {
        HStack {
            if let console = URL(string: "https://qz.sii.edu.cn/") {
                Link("Inspire 控制台", destination: console)
            }
            Spacer()
            Button("用量与支出", action: self.openUsageDashboard)
            Button("设置…", action: self.openSettings)
                .keyboardShortcut(",", modifiers: .command)
            Button("退出") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
        .padding(.vertical, 9)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(MenuHighlightStyle.card, in: RoundedRectangle(cornerRadius: 10))
    }

    private func rate(_ rate: Double?) -> String {
        rate.map { "\($0.formatted(.number.precision(.fractionLength(0...4)))) 点券/小时" } ?? "待确认"
    }

    private func depletion(_ forecast: WeeklyForecast) -> String {
        switch forecast.status {
        case .waiting: "—"
        case .stale: "等候新样本"
        case .warmingUp: "周期刚开始"
        case .lasts: "刷新前有余量"
        case .depletes: forecast.exhaustedAt.map { InspireQuota.dateText($0, format: "MM/dd HH:mm") } ?? "—"
        case .exhausted: "已耗尽"
        }
    }
}
