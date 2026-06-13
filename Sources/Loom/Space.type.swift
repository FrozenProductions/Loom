import Foundation

typealias SpaceIdentifier = UInt64

struct SpaceSnapshot: Equatable {
    let displays: [DisplaySpaces]
    let activeSpaceID: SpaceIdentifier?
    let errorMessage: String?
}

struct DisplaySpaces: Equatable, Identifiable {
    let id: String
    let name: String
    let spaces: [DesktopSpace]
}

struct DesktopSpace: Equatable, Identifiable {
    let id: SpaceIdentifier
    let number: Int
    let title: String
    let isCurrent: Bool
    let apps: [SpaceApp]
}

struct SpaceApp: Equatable, Identifiable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }
}
