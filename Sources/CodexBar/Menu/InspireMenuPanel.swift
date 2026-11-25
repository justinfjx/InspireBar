import AppKit
import InspireBarCore
import SwiftUI

/// An anchored menu surface with a fixed screen budget. The hosted view scrolls within that budget.
@MainActor
final class InspireMenuPanel: NSPanel, NSWindowDelegate {
    init(rootView: InspireMenuView) {
        let bounds = CGRect(origin: .zero, size: MenuPanelPlacement.preferredSize)
        super.init(
            contentRect: bounds,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovable = false
        self.level = .popUpMenu
        self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.identifier = NSUserInterfaceItemIdentifier("io.github.justinfjx.inspirebar.menu-panel")
        self.setAccessibilityLabel("InspireBar 点券面板")
        self.delegate = self

        let surface = NSVisualEffectView(frame: bounds)
        surface.material = .popover
        surface.state = .active
        surface.blendingMode = .behindWindow
        surface.wantsLayer = true
        surface.layer?.cornerRadius = 16
        surface.layer?.masksToBounds = true

        let host = NSHostingView(rootView: rootView)
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            host.topAnchor.constraint(equalTo: surface.topAnchor),
            host.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
        ])
        self.contentView = surface
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    static func placement(for button: NSStatusBarButton) -> CGRect? {
        var screens = NSScreen.screens
        if let main = NSScreen.main, let index = screens.firstIndex(of: main) {
            screens.remove(at: index)
            screens.insert(main, at: 0)
        }
        let anchor = button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) }
        let pointerIsClick = switch NSApp.currentEvent?.type {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp: true
        default: false
        }
        return MenuPanelPlacement.frame(
            displays: screens.map { MenuPanelPlacement.Display(frame: $0.frame, visibleFrame: $0.visibleFrame) },
            pointer: NSEvent.mouseLocation,
            pointerIsClick: pointerIsClick,
            anchor: anchor,
            menuBarHeight: max(NSStatusBar.system.thickness, anchor?.height ?? 0))
    }

    func present(at frame: CGRect) {
        self.setFrame(frame, display: false)
        self.orderFrontRegardless()
        self.makeKey()
    }

    func windowDidResignKey(_ notification: Notification) {
        self.orderOut(nil)
    }

    override func cancelOperation(_ sender: Any?) {
        self.orderOut(nil)
    }
}
