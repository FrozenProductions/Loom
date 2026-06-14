import AppKit
import CoreGraphics
import Darwin
import Foundation

final class SpaceService {
    private let privateAPI = SpacesPrivateAPI()
    private let appResolver = SpaceAppResolver()

    func currentSnapshot() -> SpaceSnapshot {
        guard let data = privateAPI.loadManagedDisplaySpaces() else {
            return SpaceSnapshot(
                displays: [],
                activeSpaceID: nil,
                errorMessage: "Spaces unavailable"
            )
        }

        let activeSpaceID = privateAPI.activeSpaceID() ?? data.detectedActiveSpaceID
        let appsByWindowID = appResolver.appsByWindowID()
        let ignoredBundleIDs = IgnoredAppsStore.bundleIDs
        let displays = data.displays.map { display in
            let spaces = display.spaces.enumerated().map { index, space in
                let windowIDs = space.windowIDs.isEmpty
                    ? privateAPI.windowIDs(for: space.id)
                    : space.windowIDs
                let apps = appResolver.apps(
                    for: windowIDs,
                    appsByWindowID: appsByWindowID,
                    ignoring: ignoredBundleIDs
                )

                return DesktopSpace(
                    id: space.id,
                    number: index + 1,
                    title: title(for: space, index: index),
                    isCurrent: space.id == activeSpaceID,
                    apps: apps
                )
            }

            return DisplaySpaces(
                id: display.id,
                name: display.name,
                spaces: spaces
            )
        }

        return SpaceSnapshot(
            displays: displays,
            activeSpaceID: activeSpaceID,
            errorMessage: displays.isEmpty ? "No Spaces found" : nil
        )
    }

    private func title(for space: RawSpace, index: Int) -> String {
        if space.kind == .fullScreen {
            return "Full Screen"
        }

        return "Desktop \(index + 1)"
    }
}

private final class SpacesPrivateAPI {
    private typealias CGSConnectionID = Int32
    private typealias CGSMainConnectionIDFunction = @convention(c) () -> CGSConnectionID
    private typealias CGSCopyManagedDisplaySpacesFunction = @convention(c) (CGSConnectionID) -> Unmanaged<CFArray>?
    private typealias CGSGetActiveSpaceFunction = @convention(c) (CGSConnectionID) -> SpaceIdentifier
    private typealias CGSCopyWindowsWithOptionsAndTagsFunction = @convention(c) (
        CGSConnectionID,
        UInt32,
        CFArray,
        UInt32,
        UnsafeMutablePointer<UInt64>?,
        UnsafeMutablePointer<UInt64>?
    ) -> Unmanaged<CFArray>?

    private let mainConnectionID: CGSMainConnectionIDFunction?
    private let copyManagedDisplaySpaces: CGSCopyManagedDisplaySpacesFunction?
    private let getActiveSpace: CGSGetActiveSpaceFunction?
    private let copyWindowsWithOptionsAndTags: CGSCopyWindowsWithOptionsAndTagsFunction?

    init() {
        let handle = dlopen(nil, RTLD_LAZY)
        mainConnectionID = Self.loadSymbol("CGSMainConnectionID", from: handle)
        copyManagedDisplaySpaces = Self.loadSymbol("CGSCopyManagedDisplaySpaces", from: handle)
        getActiveSpace = Self.loadSymbol("CGSGetActiveSpace", from: handle)
        copyWindowsWithOptionsAndTags = Self.loadSymbol("CGSCopyWindowsWithOptionsAndTags", from: handle)
    }

    func activeSpaceID() -> SpaceIdentifier? {
        guard let mainConnectionID, let getActiveSpace else { return nil }
        let id = getActiveSpace(mainConnectionID())
        return id == 0 ? nil : id
    }

    func loadManagedDisplaySpaces() -> RawSpacesData? {
        guard let mainConnectionID, let copyManagedDisplaySpaces else { return nil }
        guard let cfArray = copyManagedDisplaySpaces(mainConnectionID())?.takeRetainedValue() else { return nil }
        guard let rawDisplays = cfArray as? [[String: Any]] else { return nil }

        let displays = rawDisplays.compactMap(Self.parseDisplay)
        let currentID = displays
            .compactMap(\.currentSpaceID)
            .first

        return RawSpacesData(displays: displays, detectedActiveSpaceID: currentID)
    }

    func windowIDs(for spaceID: SpaceIdentifier) -> [UInt32] {
        guard let mainConnectionID, let copyWindowsWithOptionsAndTags else { return [] }

        var setTags: UInt64 = 0
        var clearTags: UInt64 = 0
        let spaceIDs = [NSNumber(value: spaceID)]
        guard let cfArray = copyWindowsWithOptionsAndTags(
            mainConnectionID(),
            0,
            spaceIDs as CFArray,
            SpaceWindowOptions.allSpaces,
            &setTags,
            &clearTags
        )?.takeRetainedValue() else {
            return []
        }

        return Self.uint32ArrayValue(cfArray)
    }

    private static func parseDisplay(_ dictionary: [String: Any]) -> RawDisplaySpaces? {
        let id = stringValue(dictionary["Display Identifier"])
            ?? stringValue(dictionary["Display UUID"])
            ?? stringValue(dictionary["uuid"])
            ?? UUID().uuidString

        let spaces = arrayValue(dictionary["Spaces"])
            .compactMap(parseSpace)

        let currentSpaceID = dictionaryValue(dictionary["Current Space"])
            .flatMap(parseSpace)?
            .id

        guard !spaces.isEmpty else { return nil }

        return RawDisplaySpaces(
            id: id,
            name: displayName(for: id),
            spaces: spaces,
            currentSpaceID: currentSpaceID
        )
    }

    private static func parseSpace(_ dictionary: [String: Any]) -> RawSpace? {
        guard let id = spaceID(from: dictionary) else { return nil }
        let typeValue = intValue(dictionary["type"]) ?? intValue(dictionary["TileLayoutManagerSpaceType"])
        let windowIDs = windowIDs(from: dictionary)
        return RawSpace(id: id, kind: RawSpaceKind(rawValue: typeValue ?? 0), windowIDs: windowIDs)
    }

    private static func spaceID(from dictionary: [String: Any]) -> SpaceIdentifier? {
        if let id = dictionary["ManagedSpaceID"] as? SpaceIdentifier {
            return id
        }

        if let number = dictionary["ManagedSpaceID"] as? NSNumber {
            return number.uint64Value
        }

        return nil
    }

    private static func windowIDs(from dictionary: [String: Any]) -> [UInt32] {
        let possibleKeys = ["Windows", "windows", "ManagedSpaceWindows"]
        for key in possibleKeys {
            let ids = uint32ArrayValue(dictionary[key])
            if !ids.isEmpty {
                return ids
            }
        }

        return []
    }

    private static func displayName(for id: String) -> String {
        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }

            guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
                continue
            }

            if CFUUIDCreateString(nil, uuid) as String == id {
                return screen.localizedName
            }
        }

        return "Display"
    }

    private static func dictionaryValue(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func arrayValue(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func uint32ArrayValue(_ value: Any?) -> [UInt32] {
        if let values = value as? [UInt32] {
            return values
        }

        if let values = value as? [Int] {
            return values.compactMap { UInt32(exactly: $0) }
        }

        if let values = value as? [NSNumber] {
            return values.map(\.uint32Value)
        }

        if let values = value as? [CFNumber] {
            return values.map { number in
                let nsNumber = number as NSNumber
                return nsNumber.uint32Value
            }
        }

        return []
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }

        return (value as? NSNumber)?.stringValue
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        return (value as? NSNumber)?.intValue
    }

    private static func loadSymbol<T>(_ name: String, from handle: UnsafeMutableRawPointer?) -> T? {
        guard let symbol = dlsym(handle, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}

private enum SpaceWindowOptions {
    static let allSpaces: UInt32 = 2
}

private struct RawSpacesData {
    let displays: [RawDisplaySpaces]
    let detectedActiveSpaceID: SpaceIdentifier?
}

private struct RawDisplaySpaces {
    let id: String
    let name: String
    let spaces: [RawSpace]
    let currentSpaceID: SpaceIdentifier?
}

private struct RawSpace {
    let id: SpaceIdentifier
    let kind: RawSpaceKind
    let windowIDs: [UInt32]
}

private enum RawSpaceKind: Equatable {
    case desktop
    case fullScreen
    case other(Int)

    init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .desktop
        case 4:
            self = .fullScreen
        default:
            self = .other(rawValue)
        }
    }
}

private final class SpaceAppResolver {
    func appsByWindowID() -> [UInt32: SpaceApp] {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }

        var appsByWindowID: [UInt32: SpaceApp] = [:]
        for window in windowInfo {
            guard let windowID = uint32Value(window[kCGWindowNumber as String]) else { continue }
            guard let processID = intValue(window[kCGWindowOwnerPID as String]) else { continue }
            guard let app = NSRunningApplication(processIdentifier: pid_t(processID)) else { continue }
            guard let bundleIdentifier = app.bundleIdentifier else { continue }
            guard isUserApplication(app: app) else { continue }

            appsByWindowID[windowID] = SpaceApp(
                bundleIdentifier: bundleIdentifier,
                name: app.localizedName ?? bundleIdentifier
            )
        }

        return appsByWindowID
    }

    func apps(
        for windowIDs: [UInt32],
        appsByWindowID: [UInt32: SpaceApp],
        ignoring ignoredBundleIDs: Set<String>
    ) -> [SpaceApp] {
        var seen: Set<String> = []
        var apps: [SpaceApp] = []

        for windowID in windowIDs {
            guard let app = appsByWindowID[windowID] else { continue }
            guard !ignoredBundleIDs.contains(app.bundleIdentifier) else { continue }
            guard !seen.contains(app.bundleIdentifier) else { continue }
            seen.insert(app.bundleIdentifier)
            apps.append(app)
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isUserApplication(app: NSRunningApplication) -> Bool {
        guard let appPath = app.bundleURL?.path else { return false }
        return AppLocation.isInApplicationsFolder(appPath)
    }

    private func uint32Value(_ value: Any?) -> UInt32? {
        if let value = value as? UInt32 {
            return value
        }

        if let value = value as? Int {
            return UInt32(exactly: value)
        }

        return (value as? NSNumber)?.uint32Value
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        return (value as? NSNumber)?.intValue
    }
}
