import InspireBarCore
import SwiftUI

enum MenuHighlightStyle {
    static let progressTrack = Color(nsColor: .tertiaryLabelColor).opacity(0.22)
    static let progressTint = Color(red: 73 / 255, green: 163 / 255, blue: 176 / 255)
    static let card = Color.secondary.opacity(0.08)

    static func utilizationTint(_ band: InspireInstance.Utilization.Band, scheme: ColorScheme) -> Color {
        switch (band, scheme) {
        case (.low, .dark): Color(red: 0.33, green: 0.80, blue: 0.50)
        case (.elevated, .dark): Color(red: 0.98, green: 0.78, blue: 0.32)
        case (.high, .dark): Color(red: 1, green: 0.39, blue: 0.42)
        case (.low, _): Color(red: 0.10, green: 0.60, blue: 0.30)
        case (.elevated, _): Color(red: 0.79, green: 0.56, blue: 0.07)
        case (.high, _): Color(red: 1, green: 0.27, blue: 0.29)
        }
    }
}
