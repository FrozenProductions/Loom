import SwiftUI

struct SpacePillContent: View {
    let space: DesktopSpace
    let showAppIcons: Bool
    let dockSize: DockSize

    var body: some View {
        if showAppIcons, !space.apps.isEmpty {
            HStack(spacing: -dockSize.iconOverlap) {
                ForEach(Array(space.apps.prefix(SpaceOverlayMetrics.maximumVisibleIcons))) { app in
                    AppIconView(app: app)
                        .frame(width: dockSize.iconSize, height: dockSize.iconSize)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        } else {
            Text(spaceLabel)
                .font(.system(size: dockSize.numberFontSize, weight: space.isCurrent ? .bold : .semibold, design: .default))
                .foregroundStyle(space.isCurrent ? Color.black : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var spaceLabel: String {
        space.title == "Full Screen" ? "FS" : "\(space.number)"
    }
}
