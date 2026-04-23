//
//  AppUninstallerView.swift
//  Pulse
//
//  View for uninstalling apps and their associated files.
//  Shows installed apps, search, select to uninstall, preview panel.
//

import SwiftUI

struct AppUninstallerView: View {
    @StateObject private var uninstaller = AppUninstaller()
    @State private var searchText: String = ""
    @State private var selectedApp: InstalledApp?
    @State private var showUninstallConfirmation = false
    @State private var showUninstallResult = false

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            controlsSection

            if uninstaller.isScanning {
                scanningProgressSection
            } else if uninstaller.installedApps.isEmpty {
                emptyStateSection
            } else {
                appsListSection
            }

            if let preview = uninstaller.currentPreview {
                previewSection(preview: preview)
            }
        }
        .padding()
        .onAppear {
            uninstaller.scanInstalledApps()
        }
        .alert("Uninstall \(selectedApp?.appName ?? "App")?", isPresented: $showUninstallConfirmation) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    if let app = selectedApp {
                        _ = await uninstaller.uninstall(app)
                        await MainActor.run {
                            showUninstallResult = true
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let preview = uninstaller.currentPreview {
                Text("This will move \(preview.app.appName) and \(preview.associatedFiles.count) associated files to Trash (\(preview.totalSizeText) total).")
            }
        }
        .alert(uninstaller.lastResult?.success == true ? "Uninstall Complete" : "Uninstall Failed", isPresented: $showUninstallResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uninstaller.lastResult?.summary ?? "Unknown result")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "trash.circle")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("App Uninstaller")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Text("\(uninstaller.installedApps.count) apps")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !uninstaller.isScanning {
                Button(action: { uninstaller.scanInstalledApps() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(uninstaller.isScanning)
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 300)

            Spacer()

            if uninstaller.isUninstalling {
                ProgressView()
                    .scaleEffect(0.8)
                Text(uninstaller.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Scanning State

    private var scanningProgressSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(uninstaller.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        ContentUnavailableView(
            "No Apps Found",
            systemImage: "app.badge",
            description: Text("Click Refresh to scan for installed apps")
        )
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Apps List

    private var appsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredApps) { app in
                    AppRow(
                        app: app,
                        isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier,
                        isProtected: uninstaller.isProtected(app),
                        onSelect: {
                            selectedApp = app
                            uninstaller.previewUninstall(for: app)
                        }
                    )
                }
            }
        }
        .frame(minHeight: 200)
    }

    // MARK: - Preview Section

    private func previewSection(preview: UninstallPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Uninstall Preview")
                    .font(.headline)

                Spacer()

                Text(preview.totalSizeText)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }

            Divider()

            // App bundle
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading) {
                    Text(preview.app.appName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(preview.app.appURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(preview.app.fileSizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Associated files
            if !preview.associatedFiles.isEmpty {
                Text("Associated Files (\(preview.associatedFiles.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(preview.associatedFiles) { file in
                    HStack(spacing: 8) {
                        Image(systemName: file.type.icon)
                            .foregroundStyle(Color(file.type.color))
                            .frame(width: 20)

                        VStack(alignment: .leading) {
                            Text(file.type.rawValue)
                                .font(.subheadline)
                            Text(file.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(file.sizeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else {
                Text("No associated files found in standard locations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            // Warning if app is running
            if preview.appIsRunning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(preview.app.appName) is running. Please quit it before uninstalling.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Summary
            HStack {
                Text("\(preview.itemCount) items · \(preview.totalSizeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Uninstall") {
                    showUninstallConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!preview.canUninstall || uninstaller.isUninstalling)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return uninstaller.installedApps }
        return uninstaller.installedApps.filter { app in
            app.appName.localizedCaseInsensitiveContains(searchText) ||
            app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let isProtected: Bool
    let onSelect: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // App icon placeholder
            Image(systemName: isProtected ? "lock.shield" : "app.fill")
                .font(.title3)
                .foregroundStyle(isProtected ? .orange : Color.accentColor)
                .frame(width: 24)

            // App info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(app.appName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if let version = app.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Size
            Text(app.fileSizeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            // Protection badge
            if isProtected {
                Text("Protected")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : (isHovering ? Color.secondary.opacity(0.05) : .clear))
        )
        .onTapGesture {
            if !isProtected {
                onSelect()
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .opacity(isProtected ? 0.6 : 1.0)
    }
}

// MARK: - Color extension for AssociatedFileType

extension AssociatedFileType {
    var color: String {
        switch self {
        case .applicationSupport: return "blue"
        case .containers: return "purple"
        case .groupContainers: return "cyan"
        case .caches: return "orange"
        case .preferences: return "gray"
        case .savedState: return "yellow"
        case .logs: return "red"
        }
    }
}

// MARK: - Preview

#Preview {
    AppUninstallerView()
        .frame(width: 700, height: 500)
}
