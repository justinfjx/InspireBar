import AppKit
import InspireBarCore
import Observation
import SwiftUI

@main
@MainActor
struct InspireBarApp {
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        let files = FileManager.default
        let support = files.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = Self.value("--data-dir", in: arguments).map { URL(fileURLWithPath: $0) }
            ?? support.appending(path: "InspireBar", directoryHint: .isDirectory)
        let source = Self.value("--import-archive", in: arguments).map { URL(fileURLWithPath: $0) }
        let reader = InspireReader(directory: directory, importArchive: source)
        if arguments.contains("--refresh-once") {
            Self.refreshOnce(reader)
            return
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = InspireBarDelegate(
            reader: reader,
            showMenu: arguments.contains("--show-menu"),
            showSettings: arguments.contains("--show-settings"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    private static func value(_ flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func refreshOnce(_ reader: InspireReader) {
        do {
            let snapshot = try reader.readInspire()
            guard snapshot.collectionError == nil, snapshot.latest != nil else {
                let message = snapshot.collectionError ?? "点券余额尚未返回。"
                FileHandle.standardError.write(Data((message + "\n").utf8))
                exit(1)
            }
            try FileHandle.standardOutput.write(Data(contentsOf: reader.snapshotURL))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}

@MainActor
final class InspireBarDelegate: NSObject, NSApplicationDelegate {
    private static let statusItemName = "InspireBar"

    private let store: InspireStore
    private let showMenu: Bool
    private let showSettings: Bool
    private var statusItem: NSStatusItem?
    private var menuPanel: InspireMenuPanel?
    private var menuWindow: NSWindow?
    private var settingsWindow: SettingsWindowController?
    private var countdownClock: Task<Void, Never>?

    init(reader: InspireReader, showMenu: Bool, showSettings: Bool) {
        self.store = InspireStore(reader: reader, preferences: InspirePreferences())
        self.showMenu = showMenu
        self.showSettings = showSettings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.installApplicationMenu()
        self.installStatusItem()
        self.refreshIcon()
        self.store.start()
        if self.showSettings {
            self.openSettings()
        } else if self.showMenu {
            self.showUsageWindow()
        }
        if ProcessInfo.processInfo.arguments.contains("--diagnose-menu-bar") {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.traceStatusItem()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        self.openSettings()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.countdownClock?.cancel()
        self.store.stop()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        self.menuPanel?.orderOut(nil)
    }

    private func installStatusItem() {
        // Set the stable identity before the item takes up space, as in CodexBar's status-item factory.
        let item = NSStatusBar.system.statusItem(withLength: 0)
        item.autosaveName = Self.statusItemName
        item.length = NSStatusItem.variableLength
        self.statusItem = item
        if let button = item.button {
            button.imageScaling = .scaleNone
            button.target = self
            button.action = #selector(self.toggleMenu)
            button.setAccessibilityIdentifier("inspirebar-credits")
        }
    }

    private func installApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let actions = NSMenu(title: "InspireBar")
        let about = NSMenuItem(title: "关于 InspireBar", action: #selector(self.openAbout), keyEquivalent: "")
        let settings = NSMenuItem(title: "设置…", action: #selector(self.openSettingsFromMenu), keyEquivalent: ",")
        let usage = NSMenuItem(title: "用量与支出", action: #selector(self.openUsageDashboard), keyEquivalent: "1")
        let points = NSMenuItem(title: "点券面板", action: #selector(self.showUsageWindow), keyEquivalent: "0")
        for item in [about, settings, usage, points] {
            item.target = self
        }
        actions.addItem(about)
        actions.addItem(.separator())
        actions.addItem(settings)
        actions.addItem(points)
        actions.addItem(usage)
        actions.addItem(.separator())
        actions.addItem(withTitle: "退出 InspireBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = actions
        main.addItem(appItem)
        NSApplication.shared.mainMenu = main
    }

    private func refreshIcon() {
        withObservationTracking {
            let layout = self.store.preferences.menuBarLayout
            let output = MenuBarLayoutRenderer.render(layout: layout, store: self.store)
            self.updateCountdownClock(active: layout.lines.joined().contains(.resetCountdown))
            if let item = self.statusItem, let button = item.button {
                button.imagePosition = .imageOnly
                button.image = output.image
                item.length = ceil(output.image.size.width) + 12
                button.setAccessibilityTitle("InspireBar")
                button.setAccessibilityLabel(output.accessibilityLabel)
                button.toolTip = "公共科研项目 · \(InspireQuota.points(self.store.balance)) 点券"
            }
        } onChange: { [weak self] in
            Task { @MainActor in self?.refreshIcon() }
        }
    }

    private func updateCountdownClock(active: Bool) {
        if !active {
            self.countdownClock?.cancel()
            self.countdownClock = nil
        } else if self.countdownClock == nil {
            self.countdownClock = Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(60))
                    } catch {
                        return
                    }
                    self?.store.updateClock()
                }
            }
        }
    }

    @objc private func toggleMenu() {
        if self.menuPanel?.isVisible == true {
            self.menuPanel?.orderOut(nil)
            return
        }
        guard let button = self.statusItem?.button, let frame = InspireMenuPanel.placement(for: button) else { return }

        self.store.menuDidOpen()
        self.menuWindow?.orderOut(nil)
        let panel = self.menuPanel ?? InspireMenuPanel(rootView: self.makeMenu())
        self.menuPanel = panel
        panel.present(at: frame)
    }

    @objc private func showUsageWindow() {
        self.store.menuDidOpen()
        self.menuPanel?.orderOut(nil)
        if self.menuWindow == nil {
            let size = MenuPanelPlacement.preferredSize
            let controller = NSHostingController(rootView: self.makeMenu().frame(
                width: size.width,
                height: size.height))
            let window = NSWindow(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.title = "InspireBar"
            window.titleVisibility = .hidden
            window.center()
            self.menuWindow = window
        }
        NSApplication.shared.activate()
        self.menuWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettingsFromMenu() {
        self.openSettings()
    }

    @objc private func openAbout() {
        self.openSettings(pane: .about)
    }

    @objc private func openUsageDashboard() {
        self.openSettings(pane: .usageSpend)
    }

    private func makeMenu() -> InspireMenuView {
        InspireMenuView(
            store: self.store,
            openSettings: { [weak self] in self?.openSettings() },
            openUsageDashboard: { [weak self] in self?.openUsageDashboard() })
    }

    private func openSettings(pane: SettingsPane? = nil) {
        self.menuPanel?.orderOut(nil)
        if self.settingsWindow == nil {
            self.settingsWindow = SettingsWindowController(store: self.store) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        self.settingsWindow?.open(pane: pane)
    }

    private func traceStatusItem() {
        guard let item = self.statusItem else { return }
        let window = item.button?.window
        let frame = NSStringFromRect(window?.frame ?? .zero)
        let screen = window?.screen.map { NSStringFromRect($0.frame) } ?? "none"
        let message = "InspireBar item visible=\(item.isVisible) width=\(item.button?.frame.width ?? 0) "
            + "window=\(window?.windowNumber ?? -1) frame=\(frame) screen=\(screen)\n"
        FileHandle.standardOutput.write(Data(message.utf8))
    }
}
