import AppKit
import CoreServices
import Foundation

@MainActor
final class InstalledAppsProvider: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    private var watcherToken: UUID?

    init() {
        refresh()
        watcherToken = ApplicationsFolderWatcher.shared.add { [weak self] in
            self?.refresh()
        }
    }

    deinit {
        if let token = watcherToken {
            ApplicationsFolderWatcher.shared.remove(token)
        }
    }

    func refresh() {
        apps = InstalledAppsScanner.scan()
    }
}

struct InstalledApp: Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    var id: String { bundleIdentifier }
}

private enum InstalledAppsScanner {
    static func scan() -> [InstalledApp] {
        let fileManager = FileManager.default
        let directories = [
            URL(fileURLWithPath: AppLocation.systemApplicationsPath, isDirectory: true),
            URL(fileURLWithPath: AppLocation.userApplicationsPath, isDirectory: true)
        ]

        var apps: [InstalledApp] = []
        var seenBundleIDs = Set<String>()

        for directory in directories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                guard let bundle = Bundle(url: url) else { continue }
                guard let bundleIdentifier = bundle.bundleIdentifier else { continue }
                guard seenBundleIDs.insert(bundleIdentifier).inserted else { continue }

                let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.localizedInfoDictionary?["CFBundleName"] as? String
                    ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? fileManager.displayName(atPath: url.path)

                apps.append(InstalledApp(bundleIdentifier: bundleIdentifier, name: name, url: url))
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private final class ApplicationsFolderWatcher {
    nonisolated(unsafe) static let shared = ApplicationsFolderWatcher()
    private var stream: FSEventStreamRef?
    private var callbacks: [UUID: () -> Void] = [:]
    private let lock = NSLock()

    private init() {
        start()
    }

    func add(_ callback: @escaping () -> Void) -> UUID {
        let token = UUID()
        lock.lock()
        callbacks[token] = callback
        lock.unlock()
        return token
    }

    func remove(_ token: UUID) {
        lock.lock()
        callbacks.removeValue(forKey: token)
        lock.unlock()
    }

    private func start() {
        let paths = [AppLocation.systemApplicationsPath, AppLocation.userApplicationsPath] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, _, _, _, _, _ in
                DispatchQueue.main.async {
                    ApplicationsFolderWatcher.shared.notify()
                }
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    private func notify() {
        var callbacksCopy: [() -> Void] = []
        lock.lock()
        callbacksCopy = Array(callbacks.values)
        lock.unlock()
        for callback in callbacksCopy {
            callback()
        }
    }
}
