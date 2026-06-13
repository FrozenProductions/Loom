import AppKit
import SwiftUI

@MainActor
final class SpaceOverlayPanelController {
    private let model = SpaceOverlayModel()
    private var panel: NSPanel?

    func show(snapshot: SpaceSnapshot) {
        model.snapshot = snapshot
        model.showAppIcons = UserDefaults.standard.bool(forKey: LoomDefaults.showAppIconsKey)
        model.dockSize = DockSize.current

        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: DockSize.current.panelWidth, height: DockSize.current.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(rootView: SpaceOverlayView(model: model))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
            .transient
        ]
        panel.sharingType = .none
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let screen else { return }

        let frame = screen.visibleFrame
        let size = DockSize.current
        let position = DockPosition.current
        let fittingSize = fittingPanelSize(for: model.snapshot, size: size, position: position)
        let width = min(fittingSize.width, frame.width - SpaceOverlayMetrics.edgeMargin * 2)
        let height = min(fittingSize.height, frame.height - SpaceOverlayMetrics.edgeMargin * 2)
        let origin = origin(for: position, frame: frame, width: width, height: height)

        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
    }

    private func origin(for position: DockPosition, frame: NSRect, width: CGFloat, height: CGFloat) -> CGPoint {
        switch position {
        case .bottomCenter:
            CGPoint(x: frame.midX - width / 2, y: frame.minY + SpaceOverlayMetrics.edgeMargin)
        case .topCenter:
            CGPoint(x: frame.midX - width / 2, y: frame.maxY - height - SpaceOverlayMetrics.edgeMargin)
        }
    }

    private func fittingPanelSize(
        for snapshot: SpaceSnapshot,
        size: DockSize,
        position: DockPosition
    ) -> CGSize {
        let spaces = snapshot.displays.flatMap(\.spaces)
        let spacing = itemSpacing(for: size)
        let horizontalPadding = horizontalPadding(for: size)
        let verticalPadding = verticalPadding(for: size)

        let width = max(
            size.minimumPanelWidth,
            spaces.reduce(CGFloat.zero) { $0 + pillWidth(for: $1, size: size) }
                + CGFloat(max(0, spaces.count - 1)) * spacing
                + horizontalPadding * 2
        )
        let height = max(
            size.minimumPanelHeight,
            size.pillHeight + verticalPadding * 2
        )
        return CGSize(width: width, height: height)
    }

    private func pillWidth(for space: DesktopSpace, size: DockSize) -> CGFloat {
        guard UserDefaults.standard.bool(forKey: LoomDefaults.showAppIconsKey), !space.apps.isEmpty else {
            return numberPillWidth(for: size)
        }

        let visibleIconCount = CGFloat(min(space.apps.count, SpaceOverlayMetrics.maximumVisibleIcons))
        return visibleIconCount * size.iconSize
            - max(0, visibleIconCount - 1) * size.iconOverlap
            + size.pillHorizontalPadding * 2
    }

    private func numberPillWidth(for size: DockSize) -> CGFloat {
        switch size {
        case .small: 38
        case .medium: 48
        case .large: 58
        }
    }

    private func horizontalPadding(for size: DockSize) -> CGFloat {
        return size.horizontalPanelPadding
    }

    private func verticalPadding(for size: DockSize) -> CGFloat {
        return size.horizontalPanelPadding
    }

    private func itemSpacing(for size: DockSize) -> CGFloat {
        size.horizontalItemSpacing
    }
}

private enum SpaceOverlayMetrics {
    static let edgeMargin: CGFloat = 28
    static let maximumVisibleIcons = 4
}
