import AppKit
import SwiftUI

struct ProjectNameColor: Codable, Equatable {
    static let black = Self(red: 0, green: 0, blue: 0)

    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var swatch: Color {
        Color(red: Double(self.red) / 255, green: Double(self.green) / 255, blue: Double(self.blue) / 255)
    }

    func textColor(in scheme: ColorScheme) -> Color {
        self == .black && scheme == .dark ? .primary : self.swatch
    }

    @MainActor
    static func selected(_ color: Color) -> Self? {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func byte(_ channel: CGFloat) -> UInt8 {
            UInt8((min(1, max(0, channel)) * 255).rounded())
        }
        return Self(red: byte(rgb.redComponent), green: byte(rgb.greenComponent), blue: byte(rgb.blueComponent))
    }
}
