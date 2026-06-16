import SwiftUI

struct SpaceOverlayView: View {
    let model: SpaceOverlayModel

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if let errorMessage = model.snapshot.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
            } else {
                HStack(spacing: itemSpacing) {
                    ForEach(spaces) { space in
                        SpacePill(
                            space: space,
                            showAppIcons: model.showAppIcons,
                            dockSize: model.dockSize
                        )
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
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

    private var spaces: [DesktopSpace] {
        model.snapshot.displays.flatMap(\.spaces)
    }

    private var itemSpacing: CGFloat {
        model.dockSize.horizontalItemSpacing
    }

    private var horizontalPadding: CGFloat {
        model.dockSize.horizontalPanelPadding
    }

    private var verticalPadding: CGFloat {
        model.dockSize.horizontalPanelPadding
    }

    private var panelCornerRadius: CGFloat {
        switch model.dockSize {
        case .small: 13
        case .medium: 15
        case .large: 18
        }
    }
}
