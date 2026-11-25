import AppKit

/// The ticket silhouette fills from left to right with the public project's remaining quota.
@MainActor
enum IconRenderer {
    private static let size = NSSize(width: 18, height: 18)

    static func makeIcon(remaining: Double?, stale: Bool) -> NSImage {
        let image = NSImage(size: self.size, flipped: false) { _ in
            let track = CGRect(x: 1, y: 4, width: 16, height: 10)
            let outline = Self.ticket(in: track)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: track).addClip()
            NSColor.labelColor.withAlphaComponent(stale ? 0.23 : 0.36).setFill()
            outline.fill()
            if let remaining {
                let fraction = max(0, min(1, remaining / 100))
                let width = (track.width * fraction * 2).rounded() / 2
                outline.addClip()
                NSColor.labelColor.withAlphaComponent(stale ? 0.52 : 1).setFill()
                NSBezierPath(rect: CGRect(x: track.minX, y: track.minY, width: width, height: track.height)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func ticket(in rect: CGRect) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        let notch: CGFloat = 1.55
        // Both holes stay within the bounds vertically; use the intersecting halves to cut the sides.
        path.appendOval(in: CGRect(x: rect.minX - notch, y: rect.midY - notch, width: 2 * notch, height: 2 * notch))
        path.appendOval(in: CGRect(x: rect.maxX - notch, y: rect.midY - notch, width: 2 * notch, height: 2 * notch))
        path.windingRule = .evenOdd
        return path
    }
}
