import AppKit
import Luminare
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        LuminarePane {
            GeneralSettingsSection()
            OverlaySettingsSection()
            ExclusionsSettingsSection()
        }
        .luminarePaneLayout(.stacked)
    }
}

struct GeneralSettingsSection: View {
    @AppStorage(LoomDefaults.startAtLoginKey) private var startAtLogin = false
    @State private var startAtLoginState = StartAtLogin.state

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
        LuminareSection {
            LuminareToggle(isOn: $startAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at login")
                    Text(startAtLoginDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(!StartAtLogin.isInApplicationsFolder)
            .onChange(of: startAtLogin) { _, newValue in
                let state = StartAtLogin.setEnabled(newValue)
                startAtLoginState = state
                if state == .requiresApproval {
                    StartAtLogin.openLoginItemsSettings()
                }
            }
        } header: {
            Text("General")
        } footer: {
            if !startAtLoginStatusText.isEmpty {
                Text(startAtLoginStatusText)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .luminareSectionLayout(.stacked)
        .luminareBordered(true)
        .onAppear {
            startAtLoginState = StartAtLogin.state
        }
    }
}

struct OverlaySettingsSection: View {
    @AppStorage(LoomDefaults.showAppIconsKey) private var showAppIcons = false
    @AppStorage(LoomDefaults.dockPositionKey) private var dockPosition = DockPosition.bottomCenter.rawValue
    @AppStorage(LoomDefaults.dockSizeKey) private var dockSize = DockSize.medium.rawValue
    @AppStorage(LoomDefaults.activationDelayKey) private var activationDelay = LoomDefaults.defaultActivationDelay

    private var dockPositionBinding: Binding<DockPosition> {
        Binding(
            get: { DockPosition(rawValue: dockPosition) ?? .bottomCenter },
            set: { dockPosition = $0.rawValue }
        )
    }

    private var dockSizeBinding: Binding<DockSize> {
        Binding(
            get: { DockSize(rawValue: dockSize) ?? .medium },
            set: { dockSize = $0.rawValue }
        )
    }

    private var activationDelayMsBinding: Binding<Double> {
        Binding(
            get: { activationDelay * 1000 },
            set: { activationDelay = $0 / 1000 }
        )
    }

    var body: some View {
        LuminareSection {
            LuminareCompose("Screen edge") {
                LuminarePicker(
                    elements: DockPosition.allCases,
                    selection: dockPositionBinding,
                    columns: DockPosition.allCases.count,
                    innerPadding: 2
                ) { position in
                    Text(position.title)
                        .font(.callout)
                }
                .luminareButtonHighlightOnHover(false)
                .luminareCornerRadius(12)
                .luminareButtonCornerRadius(8)
                .luminarePickerRoundedCorner(.always)
                .scaleEffect(0.92)
                .frame(width: 160, alignment: .trailing)
                .padding(.trailing, -2)
                .luminareComposeIgnoreSafeArea(edges: .trailing)
            }
            .luminareComposeStyle(.inline)

            LuminareCompose("Dock size") {
                LuminarePicker(
                    elements: DockSize.allCases,
                    selection: dockSizeBinding,
                    columns: DockSize.allCases.count,
                    innerPadding: 2
                ) { size in
                    Text(size.title)
                        .font(.callout)
                }
                .luminareButtonHighlightOnHover(false)
                .luminareCornerRadius(12)
                .luminareButtonCornerRadius(8)
                .luminarePickerRoundedCorner(.always)
                .scaleEffect(0.92)
                .frame(width: 210, alignment: .trailing)
                .padding(.trailing, -2)
                .luminareComposeIgnoreSafeArea(edges: .trailing)
            }
            .luminareComposeStyle(.inline)

            LuminareSlider(
                "Activation delay",
                value: activationDelayMsBinding,
                in: 0...LoomDefaults.maximumActivationDelay * 1000,
                step: 50,
                format: .number.precision(.fractionLength(0)),
                suffix: Text("ms")
            )
            .luminareSliderLayout(.compact(textBoxWidth: 70))

            LuminareToggle("Show app icons", isOn: $showAppIcons)

            LuminareCompose("Shortcut") {
                ShortcutBadge(title: "Hold Control")
            }
            .luminareComposeStyle(.inline)
        } header: {
            Text("Overlay")
        }
        .luminareSectionLayout(.stacked)
        .luminareBordered(true)
    }
}

struct ExclusionsSettingsSection: View {
    @State private var ignoredAppBundleIDs = IgnoredAppsStore.bundleIDArray
    @State private var selectedBundleIdentifier: String?
    @StateObject private var installedApps = InstalledAppsProvider()

    private var ignoredApps: [IgnoredApp] {
        ignoredAppBundleIDs
            .map { IgnoredApp(bundleIdentifier: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableApps: [IgnoredApp] {
        let ignored = Set(ignoredAppBundleIDs)
        return installedApps.apps
            .filter { !ignored.contains($0.bundleIdentifier) }
            .map { IgnoredApp(bundleIdentifier: $0.bundleIdentifier, name: $0.name) }
    }

    private var selectedAppName: String {
        guard let selectedBundleIdentifier,
              let app = availableApps.first(where: { $0.bundleIdentifier == selectedBundleIdentifier }) else {
            return "Choose App"
        }
        return app.name
    }

    var body: some View {
        LuminareSection(
            hasPadding: true,
            headerSpacing: 2,
            footerSpacing: 2,
            outerPadding: 12
        ) {
            LuminareCompose(alignment: .center) {
                Menu {
                    if availableApps.isEmpty {
                        Text("No apps found")
                    } else {
                        ForEach(availableApps) { app in
                            Button(app.name) {
                                selectedBundleIdentifier = app.bundleIdentifier
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedAppName)
                            .foregroundStyle(selectedBundleIdentifier == nil ? .secondary : .primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.luminareCompact)
                .fixedSize(horizontal: true, vertical: false)

                Button {
                    addSelectedApp()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.luminareCompact)
                .disabled(selectedBundleIdentifier == nil)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Exclude an app")
                    Text("Hide apps from the Space overlay.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .luminareComposeStyle(.inline)
            .padding(.vertical, 4)

            if ignoredApps.isEmpty {
                LuminareCompose(alignment: .center) {
                    HStack(spacing: 12) {
                        Image(systemName: "app.badge")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No ignored apps")
                            Text("Apps you add here will not appear as Space icons.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    EmptyView()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(ignoredApps) { app in
                    LuminareCompose(alignment: .center) {
                        HStack(spacing: 12) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

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

                            Button(role: .destructive) {
                                remove(app)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.luminareCompact)
                            .help("Remove \(app.name)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        EmptyView()
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("App Exclusions")
        }
        .luminareSectionLayout(.stacked)
        .luminareBordered(true)
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
