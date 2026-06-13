import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?
    private var hasEnteredActivationPolicy = false

    static func show() {
        if shared == nil {
            shared = SettingsWindowController()
        }

        shared?.showWindow(nil)
    }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 600, height: 500)),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        if !hasEnteredActivationPolicy {
            AppActivationPolicy.enter()
            hasEnteredActivationPolicy = true
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if hasEnteredActivationPolicy {
            AppActivationPolicy.leave()
            hasEnteredActivationPolicy = false
        }
        Self.shared = nil
    }

    private func configureWindow() {
        guard let window else { return }

        window.title = "Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .automatic
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("LoomSettingsWindow")
        window.minSize = NSSize(width: 520, height: 440)
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SettingsView())
    }
}
