import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SpaceOverlayModel: ObservableObject {
    @Published var snapshot = SpaceSnapshot(displays: [], activeSpaceID: nil, errorMessage: nil)
    @Published var showAppIcons = UserDefaults.standard.bool(forKey: LoomDefaults.showAppIconsKey)
    @Published var dockSize = DockSize.current
}

struct SpaceOverlayView: View {
    @ObservedObject var model: SpaceOverlayModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let errorMessage = model.snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                spaceLayout
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var spaceLayout: some View {
        HStack(spacing: itemSpacing) {
            ForEach(spaces) { space in
                SpacePill(
                    space: space,
                    showAppIcons: model.showAppIcons,
                    dockSize: model.dockSize
                )
            }
        }
    }

    private var spaces: [DesktopSpace] {
        model.snapshot.displays.flatMap(\.spaces)
    }

    private var itemSpacing: CGFloat {
        model.dockSize.horizontalItemSpacing
    }

    private var horizontalPadding: CGFloat {
        return model.dockSize.horizontalPanelPadding
    }

    private var verticalPadding: CGFloat {
        return model.dockSize.horizontalPanelPadding
    }

    private var panelCornerRadius: CGFloat {
        switch model.dockSize {
        case .small: 13
        case .medium: 15
        case .large: 18
        }
    }
}

private struct SpacePill: View {
    let space: DesktopSpace
    let showAppIcons: Bool
    let dockSize: DockSize

    var body: some View {
        content
            .frame(width: width, height: height)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(space.isCurrent ? .clear : .white.opacity(0.16), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var content: some View {
        if showAppIcons, !space.apps.isEmpty {
            HStack(spacing: -dockSize.iconOverlap) {
                ForEach(Array(space.apps.prefix(4))) { app in
                    AppIconView(app: app)
                        .frame(width: dockSize.iconSize, height: dockSize.iconSize)
                }
            }
        } else {
            Text(spaceLabel)
                .font(.system(size: dockSize.numberFontSize, weight: space.isCurrent ? .bold : .semibold))
                .foregroundStyle(space.isCurrent ? Color.black : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var width: CGFloat {
        if !showAppIcons || space.apps.isEmpty {
            return switch dockSize {
            case .small: 38
            case .medium: 48
            case .large: 58
            }
        }

        let visibleIconCount = CGFloat(min(space.apps.count, 4))
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

    private var spaceLabel: String {
        if space.title == "Full Screen" {
            return "FS"
        }

        return "\(space.number)"
    }

    @ViewBuilder
    private var background: some View {
        if space.isCurrent {
            Color.white
        } else {
            Color.white.opacity(0.12)
        }
    }
}

private struct AppIconView: View {
    let app: SpaceApp

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var icon: NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }

        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
