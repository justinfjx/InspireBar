import AppKit
import InspireBarCore

extension MenuBarLayoutToken {
    var title: String {
        switch self {
        case .icon: "票券图标"
        case .balance: "剩余点券"
        case .percent: "剩余比例"
        case .progressBar: "余额进度条"
        case .weeklyBill: "本周账单"
        case .currentRate: "当前速率"
        case .resetCountdown: "刷新倒计时"
        case .resetTime: "刷新时刻"
        case .estimatedRemaining: "预计余量"
        case .exhaustTime: "预计耗尽"
        case .paceReserve: "节奏余量"
        case .separator: "分隔点"
        }
    }

    var systemImage: String {
        switch self {
        case .icon: "ticket"
        case .balance: "number"
        case .percent: "percent"
        case .progressBar: "chart.bar.xaxis"
        case .weeklyBill: "chart.bar"
        case .currentRate: "speedometer"
        case .resetCountdown: "clock.arrow.circlepath"
        case .resetTime: "calendar"
        case .estimatedRemaining: "chart.line.uptrend.xyaxis"
        case .exhaustTime: "hourglass"
        case .paceReserve: "chart.xyaxis.line"
        case .separator: "circle.fill"
        }
    }
}

extension MenuBarLayoutPreset {
    var title: String {
        switch self {
        case .iconAndBalance: "票券与余额"
        case .iconOnly: "仅票券"
        case .percentAndReset: "比例与刷新"
        case .compactStacked: "紧凑双行"
        case .barsStacked: "双行进度条"
        case .stackedForecast: "双行预测"
        case .custom: "自定义"
        }
    }
}

@MainActor
enum MenuBarLayoutRenderer {
    struct Output {
        let image: NSImage
        let accessibilityLabel: String
    }

    private enum Component {
        case image(NSImage, NSSize, String)
        case text(NSAttributedString, String)

        var size: NSSize {
            switch self {
            case let .image(_, size, _): size
            case let .text(text, _): text.size()
            }
        }

        var accessibilityLabel: String {
            switch self {
            case let .image(_, _, label), let .text(_, label): label
            }
        }

        func draw(x: CGFloat, midY: CGFloat) {
            let y = midY - self.size.height / 2
            switch self {
            case let .image(image, size, _):
                image.draw(in: NSRect(origin: NSPoint(x: x, y: y), size: size))
            case let .text(text, _):
                text.draw(at: NSPoint(x: x, y: y))
            }
        }
    }

    static func render(layout: MenuBarLayout, store: InspireStore) -> Output {
        let tokens = layout.lines.filter { !$0.isEmpty }
        let isStacked = tokens.count == 2
        let rowHeight: CGFloat = isStacked ? 11 : 19
        let spacing: CGFloat = isStacked ? 4 : 5
        let size = store.preferences.display.menuBarSize
        let font = NSFont.monospacedDigitSystemFont(ofSize: size.fontSize(stacked: isStacked), weight: .medium)
        let rows = tokens.map { line in
            line.map { self.component($0, store: store, rowHeight: rowHeight, font: font) }
        }
        let widths = rows.map { row in
            row.reduce(0) { $0 + ceil($1.size.width) } + CGFloat(max(row.count - 1, 0)) * spacing
        }
        let imageSize = NSSize(width: max(18, widths.max() ?? 0), height: rowHeight * CGFloat(rows.count))
        let image = NSImage(size: imageSize, flipped: false) { _ in
            for (index, row) in rows.enumerated() {
                let center = imageSize.height - (CGFloat(index) + 0.5) * rowHeight
                var x: CGFloat = 0
                for component in row {
                    component.draw(x: x, midY: center)
                    x += ceil(component.size.width) + spacing
                }
            }
            return true
        }
        image.isTemplate = true
        let content = rows.joined().map(\.accessibilityLabel).filter { !$0.isEmpty }.joined(separator: "，")
        return Output(image: image, accessibilityLabel: "InspireBar，\(content)")
    }

    private static func component(
        _ token: MenuBarLayoutToken,
        store: InspireStore,
        rowHeight: CGFloat,
        font: NSFont)
        -> Component
    {
        let percent = store.balance.map { 100 * Double($0) / Double(InspireQuota.allowance) }
        switch token {
        case .icon:
            let stale = store.snapshot?.isFresh(at: store.now, refreshInterval: store.dataRefreshInterval)
            let icon = IconRenderer.makeIcon(remaining: percent, stale: stale == false)
            let side = min(rowHeight, 18)
            return .image(icon, NSSize(width: side, height: side), token.title)
        case .progressBar:
            let size = NSSize(width: 31, height: 7)
            let progress = Self.progressBar(remaining: percent, size: size)
            let label = "\(token.title) \(Self.percentage(percent))"
            return .image(progress, size, label)
        default:
            let value = self.text(token, store: store, percent: percent)
            let title = NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: NSColor.black])
            let label = token == .separator ? "" : "\(token.title) \(value)"
            return .text(title, label)
        }
    }

    private static func text(_ token: MenuBarLayoutToken, store: InspireStore, percent: Double?) -> String {
        switch token {
        case .icon, .progressBar: ""
        case .balance: InspireQuota.points(store.balance)
        case .percent: self.percentage(percent)
        case .weeklyBill: "账 \(InspireQuota.points(store.snapshot?.cycleSpend(at: store.now)))"
        case .currentRate:
            store.currentRate(project: InspireQuota.project).map {
                "\($0.formatted(.number.precision(.fractionLength(0...2))))/时"
            } ?? "—/时"
        case .resetCountdown:
            "刷新 \(InspireQuota.countdown(until: InspireQuota.window(at: store.now).end, at: store.now))"
        case .resetTime:
            InspireQuota.dateText(InspireQuota.window(at: store.now).end, format: "MM/dd HH:mm")
        case .estimatedRemaining: "预余 \(InspireQuota.points(store.forecast.remainingAtReset))"
        case .exhaustTime:
            switch store.forecast.status {
            case .lasts: "持续到重置"
            case .exhausted: "已耗尽"
            case .depletes:
                store.forecast.exhaustedAt.map { InspireQuota.dateText($0, format: "MM/dd HH:mm") } ?? "—"
            case .waiting, .stale, .warmingUp: "—"
            }
        case .paceReserve: self.paceText(store.forecast.pace)
        case .separator: "·"
        }
    }

    private static func paceText(_ pace: UsagePace?) -> String {
        guard let pace else { return "节奏 —" }
        let cents = Int(((pace.expectedUsedPercent - pace.actualUsedPercent)
                * Double(InspireQuota.allowance) / 100).rounded())
        return "节奏 \(cents > 0 ? "+" : "")\(InspireQuota.points(cents))"
    }

    private static func percentage(_ value: Double?) -> String {
        value.map { "\(Int(max(0, min(100, $0)).rounded()))%" } ?? "—%"
    }

    private static func progressBar(remaining: Double?, size: NSSize) -> NSImage {
        let fraction = max(0, min(1, (remaining ?? 0) / 100))
        return NSImage(size: size, flipped: false) { rect in
            let shape = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
            NSColor.black.withAlphaComponent(0.29).setFill()
            shape.fill()
            NSGraphicsContext.saveGraphicsState()
            shape.addClip()
            NSColor.black.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: rect.width * fraction, height: rect.height)).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
    }
}
