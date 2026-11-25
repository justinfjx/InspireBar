import Charts
import InspireBarCore
import SwiftUI

/// CodexBar's compact credit-history chart, sourced from Inspire's daily billing ledger.
struct CreditsHistoryChartMenuView: View {
    let days: [DailyCharge]
    let total: Int?
    var chartHeight: CGFloat = 96
    @State private var selection: Date?

    var body: some View {
        let known = self.days.filter { $0.amount != nil }
        if !known.isEmpty, known.count == self.days.count, known.allSatisfy({ $0.amount == 0 }),
           (self.total ?? 0) == 0
        {
            Text("这 \(known.count) 天没有扣费")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let first = self.days.first, let last = self.days.last, !known.isEmpty {
            let peak = known.max { ($0.amount ?? 0) < ($1.amount ?? 0) }
            Chart {
                ForEach(known) { point in
                    let amount = Double(point.amount ?? 0) / 100
                    BarMark(
                        x: .value("日期", point.date, unit: .day, calendar: InspireQuota.calendar),
                        y: .value("点券", amount),
                        width: .ratio(ChartBarHoverSelection.barWidthRatio))
                        .foregroundStyle(MenuHighlightStyle.progressTint)
                    if point.date == peak?.date, amount > 0 {
                        BarMark(
                            x: .value("日期", point.date, unit: .day, calendar: InspireQuota.calendar),
                            yStart: .value("峰值起点", amount * 0.95),
                            yEnd: .value("峰值", amount),
                            width: .ratio(ChartBarHoverSelection.barWidthRatio))
                            .foregroundStyle(Color(nsColor: .systemYellow))
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: first.date == last.date ? [first.date] : [first.date, last.date]) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(anchor: ChartAxisLabelLayout.barCenteredAnchor) {
                            ChartAxisLabelLayout.dateLabel(Text(InspireQuota.dateText(date, format: "MM/dd")))
                        }
                    }
                }
            }
            .chartXScale(
                domain: first.date...(last.date + InspireQuota.day),
                range: .plotDimension(padding: ChartAxisLabelLayout.dateLabelEdgePadding))
            .chartYScale(domain: 0...max(1, Double(peak?.amount ?? 0) / 100 * 1.08))
            .chartLegend(.hidden)
            .frame(height: self.chartHeight)
            .accessibilityLabel("逐日点券扣费")
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    self.overlay(proxy: proxy, geometry: geometry, dates: self.days.map(\.date))
                }
            }
            Text(self.detail(known: known))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text("暂时没有逐日账单")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func detail(known: [DailyCharge]) -> String {
        if let point = self.days.first(where: { $0.date == self.selection }) {
            let date = InspireQuota.dateText(point.date, format: "MM/dd")
            return point.amount.map { "\(date) · \(InspireQuota.points($0)) 点券" } ?? "\(date) · 等候账单"
        }
        let sum = known.reduce(0) { $0 + ($1.amount ?? 0) }
        if let total = self.total, total != sum, known.count == self.days.count {
            return "逐日合计 \(InspireQuota.points(sum)) · 区间合计 \(InspireQuota.points(total)) 点券"
        }
        if known.count < self.days.count {
            return "已回填 \(known.count) / \(self.days.count) 天"
        }
        return "合计 \(InspireQuota.points(self.total ?? sum)) 点券"
    }

    @ViewBuilder
    private func overlay(proxy: ChartProxy, geometry: GeometryProxy, dates: [Date]) -> some View {
        if let plot = proxy.plotFrame {
            let frame = geometry[plot]
            let bars = ChartBarHoverSelection.calendarDayBars(
                dates: dates, plotFrame: frame, calendar: InspireQuota.calendar, position: proxy.position(forX:)) ?? []
            ZStack(alignment: .topLeading) {
                if let index = dates.firstIndex(where: { $0 == self.selection }), bars.indices.contains(index) {
                    let selected = bars[index].frame
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: selected.width, height: selected.height)
                        .position(x: selected.midX, y: selected.midY)
                        .allowsHitTesting(false)
                }
                MouseLocationReader { location in
                    self.selection = location.flatMap {
                        ChartBarHoverSelection.selection(at: $0, plotFrame: frame, bars: bars)
                    }.map { dates[$0.index] }
                }
            }
        }
    }
}
