import AppKit
import CoreGraphics
import Foundation
import ServiceManagement

enum LoomDefaults {
    static let showAppIconsKey = "showAppIcons"
    static let dockPositionKey = "dockPosition"
    static let dockSizeKey = "dockSize"
    static let ignoredAppBundleIDsKey = "ignoredAppBundleIDs"
    static let startAtLoginKey = "startAtLogin"
    static let didSeedDefaultIgnoredAppsKey = "didSeedDefaultIgnoredApps"
    static let dockBundleID = "com.apple.dock"
}

enum DockPosition: String, CaseIterable, Identifiable {
    case bottomCenter
    case topCenter

    var id: Self { self }

    var title: String {
        switch self {
        case .bottomCenter: "Bottom"
        case .topCenter: "Top"
        }
    }

    static var current: DockPosition {
        let rawValue = UserDefaults.standard.string(forKey: LoomDefaults.dockPositionKey)
        return rawValue.flatMap(DockPosition.init(rawValue:)) ?? .bottomCenter
    }
}

enum DockSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: Self { self }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    var panelWidth: CGFloat {
        switch self {
        case .small: 420
        case .medium: 560
        case .large: 720
        }
    }

    var panelHeight: CGFloat {
        switch self {
        case .small: 72
        case .medium: 92
        case .large: 116
        }
    }

    var minimumPanelWidth: CGFloat {
        switch self {
        case .small: 58
        case .medium: 70
        case .large: 84
        }
    }

    var minimumPanelHeight: CGFloat {
        switch self {
        case .small: 44
        case .medium: 52
        case .large: 64
        }
    }

    var pillHeight: CGFloat {
        switch self {
        case .small: 30
        case .medium: 36
        case .large: 46
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: 19
        case .medium: 23
        case .large: 29
        }
    }

    var iconOverlap: CGFloat {
        switch self {
        case .small: 2
        case .medium: 3
        case .large: 4
        }
    }

    var pillHorizontalPadding: CGFloat {
        switch self {
        case .small: 7
        case .medium: 8
        case .large: 10
        }
    }

    var horizontalPanelPadding: CGFloat {
        switch self {
        case .small: 8
        case .medium: 10
        case .large: 12
        }
    }

    var horizontalItemSpacing: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large: 8
        }
    }

    var numberFontSize: CGFloat {
        switch self {
        case .small: 12
        case .medium: 13
        case .large: 16
        }
    }

    static var current: DockSize {
        let rawValue = UserDefaults.standard.string(forKey: LoomDefaults.dockSizeKey)
        return rawValue.flatMap(DockSize.init(rawValue:)) ?? .medium
    }
}

enum IgnoredAppsStore {
    static var bundleIDArray: [String] {
        UserDefaults.standard.stringArray(forKey: LoomDefaults.ignoredAppBundleIDsKey) ?? []
    }

    static var bundleIDs: Set<String> {
        Set(bundleIDArray)
    }

    static func save(_ bundleIDs: Set<String>) {
        UserDefaults.standard.set(
            bundleIDs.sorted(),
            forKey: LoomDefaults.ignoredAppBundleIDsKey
        )
    }

    static func seedDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: LoomDefaults.didSeedDefaultIgnoredAppsKey) else { return }
        var ids = bundleIDs
        if let loomBundleID = Bundle.main.bundleIdentifier {
            ids.insert(loomBundleID)
        }
        ids.insert(LoomDefaults.dockBundleID)
        save(ids)
        UserDefaults.standard.set(true, forKey: LoomDefaults.didSeedDefaultIgnoredAppsKey)
    }
}

enum StartAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case failed(String)

    static func == (lhs: StartAtLoginState, rhs: StartAtLoginState) -> Bool {
        switch (lhs, rhs) {
        case (.disabled, .disabled), (.enabled, .enabled), (.requiresApproval, .requiresApproval):
            return true
        case (.failed(let lhsMessage), .failed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

enum StartAtLogin {
    static var state: StartAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .disabled
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundlePath
        let applicationsDirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        return applicationsDirs.contains { path.hasPrefix($0) }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> StartAtLoginState {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return .failed(error.localizedDescription)
        }

        return state
    }

    static func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
