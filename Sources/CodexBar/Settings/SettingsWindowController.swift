import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let frameName = "InspireBar.SettingsWindow"
    private let selection = PreferencesSelection()

    init(store: InspireStore, openMenuBarSettings: @escaping () -> Void) {
        super.init(window: nil)
        let preferences = PreferencesView(
            store: store,
            selection: self.selection,
            openMenuBarSettings: openMenuBarSettings,
            updateTitle: { [weak self] title in self?.window?.title = title })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: PreferencesView.windowWidth, height: PreferencesView.windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.contentViewController = NSHostingController(rootView: preferences)
        window.contentMinSize = NSSize(width: PreferencesView.minWidth, height: PreferencesView.minHeight)
        window.title = self.selection.pane.rawValue
        window.identifier = NSUserInterfaceItemIdentifier("io.github.justinfjx.inspirebar.settings")
        window.isReleasedWhenClosed = false
        window.delegate = self
        if !window.setFrameUsingName(Self.frameName) {
            window.setContentSize(NSSize(width: PreferencesView.windowWidth, height: PreferencesView.windowHeight))
            window.center()
        }
        window.setFrameAutosaveName(Self.frameName)
        self.window = window
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func open(pane: SettingsPane? = nil) {
        if let pane { self.selection.select(pane) }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        self.window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
