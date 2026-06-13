import AppKit
import SwiftUI

private func menuBarImage() -> Image {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    var loaded = false

    for suffix in ["", "@2x"] {
        guard let url = Bundle.module.url(forResource: "LoomTemplate\(suffix)", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else {
            continue
        }
        rep.size = size
        image.addRepresentation(rep)
        loaded = true
    }

    guard loaded else {
        return Image(systemName: "rectangle.3.group")
    }

    image.isTemplate = true
    return Image(nsImage: image)
}

@main
struct LoomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Settings...") {
                SettingsWindowController.show()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Loom") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            menuBarImage()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: LoomController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        IgnoredAppsStore.seedDefaultsIfNeeded()
        applyStartAtLoginPreference()
        controller = LoomController()
        controller?.start()
    }

    private func applyStartAtLoginPreference() {
        guard StartAtLogin.isInApplicationsFolder else {
            print("Start at Login: app is not in /Applications or ~/Applications. Registration skipped.")
            return
        }
        let enabled = UserDefaults.standard.bool(forKey: LoomDefaults.startAtLoginKey)
        let state = StartAtLogin.setEnabled(enabled)
        switch state {
        case .enabled:
            print("Start at Login: enabled.")
        case .requiresApproval:
            print("Start at Login: registered but requires approval in System Settings > General > Login Items.")
        case .failed(let message):
            print("Start at Login: failed - \(message)")
        case .disabled:
            print("Start at Login: disabled.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
