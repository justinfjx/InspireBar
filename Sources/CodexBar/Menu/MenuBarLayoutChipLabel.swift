import SwiftUI

struct MenuBarLayoutChipLabel: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: self.systemImage)
                .font(.caption.weight(.medium))
            Text(self.title)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(self.isSelected ? Color.white : Color.primary)
        .background(
            Capsule(style: .continuous)
                .fill(self.isSelected ? Color.accentColor : Color.secondary.opacity(0.12)))
        .overlay(
            Capsule(style: .continuous)
                .stroke(self.isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

/// Left-aligned wrapping row layout for palette chips.
///
/// Palette chips have widely varying localized and user-defined widths. An adaptive
/// `LazyVGrid` would size them into equal columns and spread the leftover pane width between
/// them, and a plain `HStack` would push later chips outside the settings pane; this places each
/// chip at its natural width and wraps to the next row.
struct MenuBarLayoutChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    /// Pure packing rule: subview indices grouped into rows that each stay within `maxWidth`.
    /// Kept separate from `Layout` so the wrapping contract is testable without faking subviews.
    /// A chip wider than `maxWidth` still occupies its own row rather than being dropped.
    static func rows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        for (index, width) in widths.enumerated() {
            let advance = current.isEmpty ? width : spacing + width
            if !current.isEmpty, currentWidth + advance > maxWidth {
                rows.append(current)
                current = [index]
                currentWidth = width
                continue
            }
            current.append(index)
            currentWidth += advance
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = Self.rows(
            widths: sizes.map(\.width),
            maxWidth: proposal.width ?? .infinity,
            spacing: self.spacing)
        let rowWidths = rows.map { row in
            row.reduce(CGFloat.zero) { $0 + sizes[$1].width }
                + CGFloat(max(0, row.count - 1)) * self.spacing
        }
        let rowHeights = rows.map { row in
            row.reduce(CGFloat.zero) { max($0, sizes[$1].height) }
        }
        return CGSize(
            width: rowWidths.max() ?? 0,
            height: rowHeights.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * self.spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = Self.rows(widths: sizes.map(\.width), maxWidth: bounds.width, spacing: self.spacing)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.reduce(CGFloat.zero) { max($0, sizes[$1].height) }
            var x = bounds.minX
            for index in row {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size))
                x += size.width + self.spacing
            }
            y += rowHeight + self.spacing
        }
    }
}
