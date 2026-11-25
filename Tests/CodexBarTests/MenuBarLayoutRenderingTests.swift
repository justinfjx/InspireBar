import AppKit
import InspireBarCore
import SwiftUI
import Testing
@testable import InspireBar

@MainActor
struct MenuBarLayoutRenderingTests {
    @Test func `the status item renders the selected layout and keeps both rows across launches`() throws {
        _ = NSApplication.shared
        let suite = "InspireBar.MenuBarLayoutRenderingTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = InspirePreferences(defaults: defaults)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let reader = InspireReader(directory: directory, importArchive: nil)
        let sample: [String: Any] = [
            "at": Date().timeIntervalSince1970,
            "projects": [["name": InspireQuota.project, "scope": "member", "balance": 52430]],
            "active": [],
            "missing_workspaces": [],
        ]
        try JSONSerialization.data(withJSONObject: ["latest": sample]).write(to: reader.snapshotURL)
        let store = InspireStore(reader: reader, preferences: preferences)
        let single = MenuBarLayoutRenderer.render(layout: .defaultLayout, store: store)
        let layout = MenuBarLayout.defaultLayout.withTwoLines()
        preferences.menuBarLayout = layout
        let double = MenuBarLayoutRenderer.render(layout: preferences.menuBarLayout, store: store)

        #expect(single.image.size.height < double.image.size.height)
        #expect(double.image.size.height <= NSStatusBar.system.thickness)
        #expect(double.accessibilityLabel.contains("剩余点券 \(InspireQuota.points(52430))"))
        #expect(double.accessibilityLabel.contains("刷新倒计时"))
        #expect(InspirePreferences(defaults: defaults).menuBarLayout == layout)
        #expect(SettingsPane.menuBar.matches("双行"))

        if let preview = ProcessInfo.processInfo.environment["INSPIREBAR_LAYOUT_PREVIEW"] {
            let view = NSHostingView(rootView: MenuBarLayoutEditor(store: store)
                .frame(width: 530)
                .padding(16)
                .background(Color(nsColor: .windowBackgroundColor)))
            view.setFrameSize(view.fittingSize)
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: preview))
        }
    }
}
