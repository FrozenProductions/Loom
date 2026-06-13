import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(LoomDefaults.showAppIconsKey) private var showAppIcons = false
    @AppStorage(LoomDefaults.dockPositionKey) private var dockPosition = DockPosition.bottomCenter.rawValue
    @AppStorage(LoomDefaults.dockSizeKey) private var dockSize = DockSize.medium.rawValue
    @AppStorage(LoomDefaults.startAtLoginKey) private var startAtLogin = false
    @State private var startAtLoginState = StartAtLogin.state
    @State private var ignoredAppBundleIDs = IgnoredAppsStore.bundleIDArray
    @State private var selectedBundleIdentifier: String?

    private var ignoredApps: [IgnoredApp] {
        ignoredAppBundleIDs
            .map { IgnoredApp(bundleIdentifier: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableApps: [IgnoredApp] {
        let ignored = Set(ignoredAppBundleIDs)
        var seen: Set<String> = []
        return NSWorkspace.shared.runningApplications
            .compactMap { app -> IgnoredApp? in
                guard let id = app.bundleIdentifier, !ignored.contains(id) else { return nil }
                return IgnoredApp(bundleIdentifier: id, name: app.localizedName ?? id)
            }
            .filter { seen.insert($0.bundleIdentifier).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var startAtLoginDescription: String {
        if StartAtLogin.isInApplicationsFolder {
            return "Open Loom automatically when you log in."
        }
        return "Move Loom to /Applications or ~/Applications to enable auto-start."
    }

    private var startAtLoginStatusText: String {
        switch startAtLoginState {
        case .requiresApproval:
            return "Approval required in System Settings > General > Login Items."
        case .failed(let message):
            return "Could not enable: \(message)"
        default:
            return ""
        }
    }

    var body: some View {
        Form {
            Section("General") {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        SettingsRowLabel(
                            title: "Start at login",
                            description: startAtLoginDescription
                        )
                        if !startAtLoginStatusText.isEmpty {
                            Text(startAtLoginStatusText)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                    Toggle(isOn: $startAtLogin) { EmptyView() }
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!StartAtLogin.isInApplicationsFolder)
                }
                .contentShape(.rect)
                .onTapGesture {
                    guard StartAtLogin.isInApplicationsFolder else { return }
                    startAtLogin.toggle()
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                .onChange(of: startAtLogin) { _, newValue in
                    let state = StartAtLogin.setEnabled(newValue)
                    startAtLoginState = state
                    if state == .requiresApproval {
                        StartAtLogin.openLoginItemsSettings()
                    }
                }
                .onAppear {
                    startAtLoginState = StartAtLogin.state
                }
            }

            Section("Overlay") {
                HStack(alignment: .center, spacing: 16) {
                    SettingsRowLabel(
                        title: "Screen edge",
                        description: "Choose where the Spaces dock appears while Control is held."
                    )
                    Spacer()
                    Picker("Position", selection: $dockPosition) {
                        ForEach(DockPosition.allCases) { position in
                            Text(position.title).tag(position.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 150)
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                HStack(alignment: .center, spacing: 16) {
                    SettingsRowLabel(
                        title: "Dock size",
                        description: "Tune the overlay for compact, balanced, or larger displays."
                    )
                    Spacer()
                    Picker("Size", selection: $dockSize) {
                        ForEach(DockSize.allCases) { size in
                            Text(size.title).tag(size.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 190)
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                HStack(alignment: .center, spacing: 16) {
                    SettingsRowLabel(
                        title: "Show app icons",
                        description: "Replace Space numbers with icons for apps detected on each Space."
                    )
                    Spacer()
                    Toggle(isOn: $showAppIcons) { EmptyView() }
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .contentShape(.rect)
                .onTapGesture { showAppIcons.toggle() }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                LabeledContent("Shortcut") {
                    ShortcutBadge(title: "Hold Control")
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                if showAppIcons {
                    SettingsInfoCallout(
                        systemImage: "exclamationmark.triangle",
                        title: "App icons may fall back to numbers",
                        description: "Per-Space app icons use private macOS Spaces data. If macOS withholds window membership for a Space, Loom keeps the dock usable by showing the Space number."
                    )
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                }
            }

            Section("App Exclusions") {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsRowLabel(
                        title: "Exclude an app",
                        description: "Ignored apps are hidden from Loom icon detection, which keeps utility windows and background apps out of the overlay."
                    )

                    HStack(spacing: 10) {
                        Picker("Application", selection: $selectedBundleIdentifier) {
                            Text(availableApps.isEmpty ? "No running apps available" : "Choose App")
                                .tag(String?.none)
                            ForEach(availableApps) { app in
                                Text(app.name).tag(Optional(app.bundleIdentifier))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            addSelectedApp()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .controlSize(.small)
                        .disabled(selectedBundleIdentifier == nil)
                    }
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                if ignoredApps.isEmpty {
                    SettingsEmptyState(
                        systemImage: "app.badge",
                        title: "No ignored apps",
                        description: "Apps you add here will stop appearing as Space icons."
                    )
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                } else {
                    ForEach(ignoredApps) { app in
                        IgnoredAppRow(app: app) {
                            remove(app)
                        }
                        .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .frame(minWidth: 520, minHeight: 520)
    }

    private func addSelectedApp() {
        guard let selectedBundleIdentifier else { return }
        var ignored = Set(ignoredAppBundleIDs)
        ignored.insert(selectedBundleIdentifier)
        ignoredAppBundleIDs = ignored.sorted()
        IgnoredAppsStore.save(ignored)
        self.selectedBundleIdentifier = nil
    }

    private func remove(_ app: IgnoredApp) {
        var ignored = Set(ignoredAppBundleIDs)
        ignored.remove(app.bundleIdentifier)
        ignoredAppBundleIDs = ignored.sorted()
        IgnoredAppsStore.save(ignored)
    }
}

private struct IgnoredApp: Identifiable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }

    init(bundleIdentifier: String, name: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name ?? Self.name(for: bundleIdentifier)
    }

    var icon: NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return NSWorkspace.shared.icon(for: .applicationBundle)
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    private static func name(for bundleIdentifier: String) -> String {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return bundleIdentifier
        }
        return FileManager.default.displayName(atPath: appURL.path)
    }
}

private struct IgnoredAppRow: View {
    let app: IgnoredApp
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove \(app.name)")
        }
        .padding(.vertical, 3)
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsEmptyState: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            SettingsRowLabel(title: title, description: description)
        }
        .padding(.vertical, 8)
    }
}

private struct SettingsInfoCallout: View {
    let systemImage: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
                .frame(width: 20)

            SettingsRowLabel(title: title, description: description)
        }
        .padding(.vertical, 4)
    }
}

private struct ShortcutBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.separator.opacity(0.5))
            }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
