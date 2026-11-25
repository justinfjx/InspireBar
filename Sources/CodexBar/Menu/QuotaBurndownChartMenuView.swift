import Charts
import InspireBarCore
import SwiftUI

struct QuotaBurndownChartMenuView: View {
    let actual: [BalanceSample]
    let forecast: WeeklyForecast
    var chartHeight: CGFloat = 103

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(self.actual) { point in
                    LineMark(
                        x: .value("日期", point.at),
                        y: .value("点券", Double(point.balance) / 100),
                        series: .value("曲线", "实测"))
                        .foregroundStyle(MenuHighlightStyle.progressTint)
                }
                if let last = self.actual.last {
                    PointMark(x: .value("日期", last.at), y: .value("点券", Double(last.balance) / 100))
                        .foregroundStyle(MenuHighlightStyle.progressTint)
                }
                ForEach(self.forecast.curve) { point in
                    LineMark(
                        x: .value("日期", point.at),
                        y: .value("点券", Double(point.balance) / 100),
                        series: .value("曲线", "预测"))
                        .foregroundStyle(MenuHighlightStyle.progressTint)
                        .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
                }
            }
            .chartXScale(domain: self.forecast.window.start...self.forecast.window.end)
            .chartYScale(domain: 0...Double(max(InspireQuota.allowance, self.actual.map(\.balance).max() ?? 0)) / 100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 336, 672]) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartLegend(.hidden)
            .frame(height: self.chartHeight)
            .accessibilityLabel("本周期实测余额和刷新前预测")
            HStack {
                ChartAxisLabelLayout.dateLabel(Text(InspireQuota.dateText(self.forecast.window.start, format: "MM/dd")))
                Spacer()
                ChartAxisLabelLayout.dateLabel(Text(InspireQuota.dateText(
                    self.forecast.window.end,
                    format: "MM/dd HH:mm")))
            }
            HStack(spacing: 12) {
                Label("实测余额", systemImage: "minus")
                if let rate = self.forecast.pointsPerDay {
                    let perDay = rate.formatted(.number.precision(.fractionLength(2)))
                    Label("预测 · 本周期日均 \(perDay) 点券", systemImage: "ellipsis")
                } else if !self.forecast.curve.isEmpty {
                    Label("预测", systemImage: "ellipsis")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
