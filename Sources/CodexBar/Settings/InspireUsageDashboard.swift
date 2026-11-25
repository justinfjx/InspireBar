import AppKit
import InspireBarCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct InspireUsageDashboard: View {
    let store: InspireStore
    let selection: PreferencesSelection
    @State private var dayCount: Int
    @State private var exportError: String?

    init(store: InspireStore, selection: PreferencesSelection) {
        self.store = store
        self.selection = selection
        self._dayCount = State(initialValue: store.preferences.historyDays)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot = self.store.snapshot, let projects = snapshot.latest?.projects,
                   let project = projects.first(where: { $0.name == self.selection.projectName }) ?? projects.first
                {
                    self.controls(project: project, projects: projects)
                    self.overview(project: project, snapshot: snapshot)
                    self.history(project: project, snapshot: snapshot)
                    if project.name == InspireQuota.project {
                        self.forecast(snapshot)
                    }
                    self.comparison(projects: projects, snapshot: snapshot)
                } else {
                    ContentUnavailableView(
                        "正在等待读取 Inspire 点券",
                        systemImage: "chart.bar.xaxis",
                        description: self.store.statusMessage.map { Text($0) })
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(22)
            .frame(maxWidth: 950)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: self.store.preferences.historyDays) { _, days in self.dayCount = days }
        .alert("无法导出账单", isPresented: Binding(
            get: { self.exportError != nil },
            set: { if !$0 { self.exportError = nil } }))
        {
            Button("好", role: .cancel) {}
        } message: {
            Text(self.exportError ?? "")
        }
    }

    private func controls(project: InspireProject, projects: [InspireProject]) -> some View {
        HStack {
            Picker("项目", selection: Binding(
                get: { project.name },
                set: { self.selection.selectDestination(.project($0)) }))
            {
                ForEach(projects) { item in Text(item.name).tag(item.name) }
            }
            .fixedSize()
            Spacer()
            Picker("账单范围", selection: self.$dayCount) {
                ForEach(InspirePreferences.historyRanges, id: \.self) { Text("\($0) 天").tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            Button {
                Task { await self.store.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .disabled(self.store.isRefreshing)
            .help("刷新 Inspire 点券")
        }
    }

    private func overview(project: InspireProject, snapshot: InspireSnapshot) -> some View {
        let rate = self.store.currentRate(project: project.name)
        return HStack(spacing: 12) {
            self.metric(project.isPersonal ? "个人可用点券" : "项目共享余额", value: InspireQuota.points(project.balance))
            self.metric("区间已扣点券", value: InspireQuota.points(
                snapshot.billingTotal(project: project.name, dayCount: self.dayCount)))
            self.metric("点券／小时", value: rate?.formatted(.number.precision(.fractionLength(0...4))) ?? "—")
        }
    }

    private func history(project: InspireProject, snapshot: InspireSnapshot) -> some View {
        let days = snapshot.charges(project: project.name, dayCount: self.dayCount, at: self.store.now)
        return self.card {
            HStack {
                Text("点券账单").font(.headline)
                Spacer()
                Button("导出 CSV…") { self.export(days) }
                    .disabled(days.allSatisfy { $0.amount == nil })
            }
            CreditsHistoryChartMenuView(
                days: days,
                total: snapshot.billingTotal(project: project.name, dayCount: self.dayCount),
                chartHeight: 138)
                .id("\(project.name)/\(self.dayCount)")
            if let message = snapshot.billingError {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func forecast(_ snapshot: InspireSnapshot) -> some View {
        let forecast = self.store.forecast
        return self.card {
            HStack {
                Text("本周余额与预测").font(.headline)
                Spacer()
                Text("刷新前预计剩余 \(InspireQuota.points(forecast.remainingAtReset)) 点券")
                    .foregroundStyle(.secondary)
            }
            QuotaBurndownChartMenuView(
                actual: snapshot.balanceHistory(in: forecast.window), forecast: forecast, chartHeight: 155)
        }
    }

    private func comparison(projects: [InspireProject], snapshot: InspireSnapshot) -> some View {
        self.card {
            Text("按项目").font(.headline)
            ForEach(projects) { project in
                let amount = snapshot.billingTotal(project: project.name, dayCount: self.dayCount)
                MetricRow(title: project.name, value: "\(InspireQuota.points(amount)) 点券")
            }
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        self.card {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
        }
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(MenuHighlightStyle.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func export(_ days: [DailyCharge]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "InspireBar-账单.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let rows = days.map { day in
            let date = InspireQuota.dateText(day.date, format: "yyyy-MM-dd")
            let amount = day.amount.map {
                String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double($0) / 100)
            } ?? ""
            return "\(date),\(amount)"
        }
        do {
            try Data((["date,points"] + rows).joined(separator: "\n").appending("\n").utf8)
                .write(to: url, options: .atomic)
        } catch {
            self.exportError = error.localizedDescription
        }
    }
}
