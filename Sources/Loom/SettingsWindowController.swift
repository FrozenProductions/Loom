import AppKit
import Luminare
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
        let window = LuminareWindow {
            SettingsView()
        }

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
        window.setFrameAutosaveName("LoomSettingsWindow")
        window.setContentSize(NSSize(width: 520, height: 620))
        window.minSize = NSSize(width: 480, height: 480)
        window.isMovableByWindowBackground = true
        window.delegate = self
    }
}
