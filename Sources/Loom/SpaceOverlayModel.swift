import SwiftUI

@MainActor
@Observable
final class SpaceOverlayModel {
    var snapshot = SpaceSnapshot(displays: [], activeSpaceID: nil, errorMessage: nil)
    var showAppIcons = UserDefaults.standard.bool(forKey: LoomDefaults.showAppIconsKey)
    var dockSize = DockSize.current
}
