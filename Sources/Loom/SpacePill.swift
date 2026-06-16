import SwiftUI

struct SpacePill: View {
    let space: DesktopSpace
    let showAppIcons: Bool
    let dockSize: DockSize

    var body: some View {
        SpacePillContent(space: space, showAppIcons: showAppIcons, dockSize: dockSize)
            .frame(width: width, height: height)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(space.isCurrent ? .white : .white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(space.isCurrent ? .clear : .white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .white.opacity(space.isCurrent ? 0.25 : 0), radius: 6, x: 0, y: 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: space.isCurrent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(space.isCurrent ? [.isSelected] : [])
    }

    private var width: CGFloat {
        if !showAppIcons || space.apps.isEmpty {
            return switch dockSize {
            case .small: 38
            case .medium: 48
            case .large: 58
            }
        }

        let visibleIconCount = CGFloat(min(space.apps.count, SpaceOverlayMetrics.maximumVisibleIcons))
        return visibleIconCount * dockSize.iconSize
            - max(0, visibleIconCount - 1) * dockSize.iconOverlap
    }

    private var height: CGFloat {
        dockSize.pillHeight
    }

    private var horizontalPadding: CGFloat {
        dockSize.pillHorizontalPadding
    }

    private var verticalPadding: CGFloat {
        0
    }

    private var cornerRadius: CGFloat {
        switch dockSize {
        case .small: 9
        case .medium: 10
        case .large: 12
        }
    }

    private var accessibilityLabel: String {
        space.title == "Full Screen" ? "Full Screen Space" : "Space \(space.number)"
    }

    private var accessibilityHint: String {
        space.isCurrent ? "Current space" : "Switch to this space"
    }
}
