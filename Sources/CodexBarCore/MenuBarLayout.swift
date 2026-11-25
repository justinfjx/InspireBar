import Foundation

package enum MenuBarLayoutToken: String, Codable, CaseIterable, Sendable {
    case icon
    case balance
    case percent
    case progressBar
    case weeklyBill
    case currentRate
    case resetCountdown
    case resetTime
    case estimatedRemaining
    case exhaustTime
    case paceReserve
    case separator

    fileprivate var showsValue: Bool {
        self != .separator
    }
}

package struct MenuBarLayoutPosition: Codable, Hashable, Sendable {
    package let line: Int
    package let index: Int

    package init(line: Int, index: Int) {
        self.line = line
        self.index = index
    }
}

package struct MenuBarLayout: Codable, Hashable, Sendable {
    package static let defaultLayout = Self(lines: [[.icon, .balance]])
    package static let iconOnly = Self(lines: [[.icon]])
    package let lines: [[MenuBarLayoutToken]]

    package init(lines: [[MenuBarLayoutToken]]) {
        if let first = lines.firstIndex(where: { $0.contains(where: \.showsValue) }) {
            self.lines = Array(lines[first...].prefix(2))
        } else {
            self.lines = [[.icon, .balance]]
        }
    }

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(lines: container.decode([[MenuBarLayoutToken]].self, forKey: .lines))
    }

    package func token(at position: MenuBarLayoutPosition) -> MenuBarLayoutToken? {
        guard self.lines.indices.contains(position.line), self.lines[position.line].indices.contains(position.index)
        else { return nil }
        return self.lines[position.line][position.index]
    }

    package func inserting(
        _ token: MenuBarLayoutToken,
        at target: MenuBarLayoutPosition,
        from source: MenuBarLayoutPosition? = nil)
        -> Self
    {
        guard self.lines.indices.contains(target.line) else { return self }
        var lines = self.lines
        var index = min(max(target.index, 0), lines[target.line].count)
        if let source {
            guard self.token(at: source) == token else { return self }
            lines[source.line].remove(at: source.index)
            if source.line == target.line, source.index < index {
                index -= 1
            }
        }
        lines[target.line].insert(token, at: index)
        return Self(lines: lines)
    }

    package func appending(_ token: MenuBarLayoutToken) -> Self {
        let line = self.lines.count - 1
        return self.inserting(token, at: MenuBarLayoutPosition(line: line, index: self.lines[line].count))
    }

    package func removing(at position: MenuBarLayoutPosition) -> Self {
        guard self.token(at: position) != nil else { return self }
        var lines = self.lines
        lines[position.line].remove(at: position.index)
        guard lines.joined().contains(where: \.showsValue) else { return self }
        return Self(lines: lines)
    }

    package func withTwoLines() -> Self {
        guard self.lines.count == 1, let line = self.lines.first else { return self }
        let values = line.indices.filter { line[$0] != .icon && line[$0].showsValue }
        if values.count >= 2 {
            return self.addingLineBreak(at: values[values.count / 2])
        }
        let secondLine: MenuBarLayoutToken = line.contains(.balance) ? .resetCountdown : .balance
        return Self(lines: [line, [secondLine]])
    }

    package func addingLineBreak(at requestedIndex: Int? = nil) -> Self {
        guard self.lines.count == 1, let line = self.lines.first else { return self }
        let index = min(max(requestedIndex ?? line.count / 2, 1), line.count)
        return Self(lines: [Array(line[..<index]), Array(line[index...])])
    }

    package func removingLineBreak() -> Self {
        Self(lines: [Array(self.lines.joined())])
    }

    private enum CodingKeys: String, CodingKey {
        case lines
    }
}

package enum MenuBarLayoutPreset: String, CaseIterable, Sendable {
    case iconAndBalance
    case iconOnly
    case percentAndReset
    case compactStacked
    case barsStacked
    case stackedForecast
    case custom

    package var layout: MenuBarLayout? {
        switch self {
        case .iconAndBalance: .defaultLayout
        case .iconOnly: .iconOnly
        case .percentAndReset: MenuBarLayout(lines: [[.icon, .percent, .separator, .resetCountdown]])
        case .compactStacked: MenuBarLayout(lines: [[.balance, .percent], [.resetCountdown]])
        case .barsStacked: MenuBarLayout(lines: [[.progressBar, .percent], [.resetCountdown]])
        case .stackedForecast: MenuBarLayout(lines: [[.balance, .percent], [.estimatedRemaining, .resetCountdown]])
        case .custom: nil
        }
    }

    package static func matching(_ layout: MenuBarLayout) -> Self {
        allCases.first { $0.layout == layout } ?? .custom
    }
}
