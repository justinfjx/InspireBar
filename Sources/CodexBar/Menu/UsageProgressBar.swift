import SwiftUI

/// CodexBar's Canvas progress fill and contrasting weekly pace stripe.
struct UsageProgressBar: View {
    let percent: Double
    let pacePercent: Double?
    let stale: Bool
    let fill: InspireProgressFill

    var body: some View {
        let clamped = min(100, max(0, self.percent))
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let corner = CGSize(width: size.height / 2, height: size.height / 2)
            let track = Path(roundedRect: rect, cornerSize: corner)
            context.clip(to: track)
            context.fill(track, with: .color(MenuHighlightStyle.progressTrack))
            let fillWidth = size.width * clamped / 100
            let fill = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
            context.fill(Path(roundedRect: fill, cornerSize: corner), with: .color(
                self.stale ? .secondary : MenuHighlightStyle.progressTint))
            if let pacePercent, pacePercent > 0, pacePercent < 100 {
                let x = size.width * pacePercent / 100
                context.blendMode = .destinationOut
                context.fill(Path(CGRect(x: x - 3, y: 0, width: 6, height: size.height)), with: .color(.white))
                context.blendMode = .normal
                context.fill(Path(CGRect(x: x - 1, y: 0, width: 2, height: size.height)), with: .color(.secondary))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("本周期\(self.fill.title)比例")
        .accessibilityValue("\(Int(clamped.rounded()))%")
    }
}
