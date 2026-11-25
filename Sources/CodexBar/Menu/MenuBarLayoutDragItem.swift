import CoreTransferable
import InspireBarCore
import UniformTypeIdentifiers

extension UTType {
    static let inspireBarMenuLayoutItem = UTType(exportedAs: "io.github.justinfjx.inspirebar.menu-layout-item")
}

struct MenuBarLayoutDragItem: Codable, Hashable, Transferable, Sendable {
    enum Content: Codable, Hashable, Sendable {
        case token(MenuBarLayoutToken)
        case lineBreak
    }

    let content: Content
    let source: MenuBarLayoutPosition?
    let sourceLayout: MenuBarLayout?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .inspireBarMenuLayoutItem)
    }

    static func palette(_ token: MenuBarLayoutToken) -> Self {
        Self(content: .token(token), source: nil, sourceLayout: nil)
    }

    static func placed(
        _ token: MenuBarLayoutToken,
        at position: MenuBarLayoutPosition,
        in layout: MenuBarLayout) -> Self
    {
        Self(content: .token(token), source: position, sourceLayout: layout)
    }

    static let lineBreak = Self(content: .lineBreak, source: nil, sourceLayout: nil)
}
