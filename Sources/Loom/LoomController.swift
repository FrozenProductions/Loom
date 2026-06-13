import AppKit
import Foundation

@MainActor
final class LoomController {
    private let spaceService = SpaceService()
    private let overlayController = SpaceOverlayPanelController()
    private var keyboardMonitor: ControlKeyMonitor?
    private var refreshTimer: Timer?
    private var spaceChangeObserver: NSObjectProtocol?
    private var isOverlayVisible = false

    func start() {
        keyboardMonitor = ControlKeyMonitor { [weak self] isPressed in
            guard let self else { return }
            if isPressed {
                showOverlayAndStartRefreshing()
                return
            }

            hideOverlayAndStopRefreshing()
        }

        keyboardMonitor?.start()
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOverlayVisible else { return }
                self.refreshOverlay()
            }
        }
    }

    func stop() {
        keyboardMonitor?.stop()
        hideOverlayAndStopRefreshing()
        if let spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceChangeObserver)
        }
        spaceChangeObserver = nil
    }

    private func showOverlayAndStartRefreshing() {
        isOverlayVisible = true
        refreshOverlay()
        startRefreshTimer()
    }

    private func hideOverlayAndStopRefreshing() {
        isOverlayVisible = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        overlayController.hide()
    }

    private func refreshOverlay() {
        let snapshot = spaceService.currentSnapshot()
        overlayController.show(snapshot: snapshot)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isOverlayVisible else { return }
                self.refreshOverlay()
            }
        }
    }
}
