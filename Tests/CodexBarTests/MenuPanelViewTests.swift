import AppKit
import InspireBarCore
import SwiftUI
import Testing
@testable import InspireBar

@MainActor
struct MenuPanelViewTests {
    @Test func `a long instance list scrolls independently of the bounded panel`() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let data = try JSONSerialization.data(withJSONObject: Self.snapshot())
        try data.write(to: directory.appendingPathComponent("snapshot.json"))
        let suite = "InspireBar.MenuPanelViewTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preview = ProcessInfo.processInfo.environment["INSPIREBAR_PANEL_PREVIEW"].map { URL(fileURLWithPath: $0) }
        let preferences = InspirePreferences(defaults: defaults)
        if preview != nil {
            let row = ProjectNameColorRow(
                project: InspireQuota.project, account: "demo-account", preferences: preferences)
            row.colorSelection.wrappedValue = ProjectNameColor(red: 176, green: 53, blue: 162).swatch
        }
        let store = InspireStore(
            reader: InspireReader(directory: directory, importArchive: nil),
            preferences: preferences)
        let panel = InspireMenuPanel(rootView: InspireMenuView(
            store: store,
            openSettings: {},
            openUsageDashboard: {}))
        panel.appearance = NSAppearance(named: .aqua)
        panel.setContentSize(CGSize(width: 396, height: 368))
        let surface = try #require(panel.contentView)
        surface.layoutSubtreeIfNeeded()

        let scroll = try #require(Self.scrollView(in: surface))
        let document = try #require(scroll.documentView)
        let viewport = surface.convert(scroll.bounds, from: scroll)
        #expect(surface.bounds.size == CGSize(width: 396, height: 368))
        #expect(viewport.minY > surface.bounds.minY)
        #expect(viewport.maxY < surface.bounds.maxY)
        #expect(document.frame.height > scroll.contentView.bounds.height)

        if let preview {
            try Self.render(surface, to: preview)
        }

        let initial = scroll.contentView.bounds.origin
        let endY = document.frame.maxY - scroll.contentView.bounds.height
        let startsAtMinimum = initial.y < endY / 2
        if let preview {
            let groups = preview.deletingPathExtension().appendingPathExtension("instance-groups.png")
            let groupY = initial.y + (startsAtMinimum ? 224 : -224)
            scroll.contentView.scroll(to: CGPoint(x: initial.x, y: groupY))
            scroll.reflectScrolledClipView(scroll.contentView)
            try Self.render(surface, to: groups)
        }
        let targetY = startsAtMinimum ? endY : document.frame.minY
        scroll.contentView.scroll(to: CGPoint(x: initial.x, y: targetY))
        scroll.reflectScrolledClipView(scroll.contentView)
        #expect(scroll.contentView.bounds.origin != initial)
        #expect(surface.convert(scroll.bounds, from: scroll) == viewport)
        #expect(panel.isVisible == false)

        if let preview {
            let instances = preview.deletingPathExtension().appendingPathExtension("instances.png")
            try Self.render(surface, to: instances)
            panel.appearance = NSAppearance(named: .darkAqua)
            surface.layoutSubtreeIfNeeded()
            let dark = preview.deletingPathExtension().appendingPathExtension("instances-dark.png")
            try Self.render(surface, to: dark)
            let dashboard = preview.deletingPathExtension().appendingPathExtension("usage.png")
            try Self.renderSettings(.usageSpend, store: store, to: dashboard)
            let colors = preview.deletingPathExtension().appendingPathExtension("project-colors.png")
            try Self.renderSettings(.menu, store: store, to: colors)
        }
    }

    private static func scrollView(in view: NSView) -> NSScrollView? {
        (view as? NSScrollView) ?? view.subviews.lazy.compactMap { Self.scrollView(in: $0) }.first
    }

    private static func render(_ surface: NSView, to url: URL) throws {
        let bitmap = try #require(surface.bitmapImageRepForCachingDisplay(in: surface.bounds))
        surface.cacheDisplay(in: surface.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }

    private static func renderSettings(_ pane: SettingsPane, store: InspireStore, to url: URL) throws {
        let selection = PreferencesSelection()
        selection.select(pane)
        let view = PreferencesView(store: store, selection: selection, openMenuBarSettings: {}, updateTitle: { _ in })
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
        let host = NSHostingView(rootView: view)
        let size = CGSize(width: 880, height: pane == .menu ? 790 : 690)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        host.setFrameSize(size)
        host.layoutSubtreeIfNeeded()
        try Self.render(host, to: url)
        #expect(window.isVisible == false)
    }

    private static func snapshot() -> [String: Any] {
        let now = Date()
        let window = InspireQuota.window(at: now)
        let balance = 58400
        let days = Dictionary(uniqueKeysWithValues: (0..<30).map { offset in
            let date = InspireQuota.calendar.startOfDay(for: now) - Double(offset) * InspireQuota.day
            let spend = (offset * 31 % 19) * 180
            return (InspireQuota.dateText(date, format: "yyyy-MM-dd"), ["spend": [InspireQuota.project: spend]])
        })
        let cpuSamples = [0.245, 0.6, 0.8]
        let gpuSamples = [0.836, 0.579, 0.742]
        let active = (1...28).map { index -> [String: Any] in
            let sample = (index - 1) % cpuSamples.count
            return [
                "identifier": "fixture-\(index)",
                "name": "gpu-demo-\(index)",
                "project": InspireQuota.project,
                "workspace": "GPU 测试空间",
                "cards": 1,
                "gpu_type": "NVIDIA L40S (45GB)",
                "priority": index <= 2 ? 4 : 3,
                "priority_level": "LOW",
                "rate": 0.33,
                "cpu_utilization": cpuSamples[sample],
                "gpu_utilization": gpuSamples[sample],
            ]
        }
        return [
            "account": "demo-account",
            "latest": [
                "at": now.timeIntervalSince1970,
                "projects": [
                    ["name": InspireQuota.project, "scope": "member", "balance": balance],
                    ["name": "Demo Lab", "scope": "shared", "balance": 23300],
                ],
                "active": active,
                "missing_workspaces": [],
            ],
            "samples": [[window.start.timeIntervalSince1970, 67200], [now.timeIntervalSince1970, balance]],
            "days": days,
            "billing": [
                "at": now.timeIntervalSince1970,
                "cycle": ["start": window.start.timeIntervalSince1970, "spend": [InspireQuota.project: 6170]],
                "ranges": ["30": [InspireQuota.project: 55740, "Demo Lab": 3240]],
            ],
        ]
    }
}
