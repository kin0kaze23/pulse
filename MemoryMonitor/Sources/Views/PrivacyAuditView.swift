import SwiftUI

/// Privacy Permissions Audit View
struct PrivacyAuditView: View {
    @StateObject private var auditService = PermissionsAuditService.shared

    @State private var selectedApp: String?
    @State private var searchText: String = ""
    @State private var selectedCategory: PermissionCategory?

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            fdaStatusSection
            controlsSection

            if auditService.isScanning {
                scanningSection
            } else if auditService.appPermissions.isEmpty {
                emptyStateSection
            } else {
                permissionsListSection
            }
        }
        .padding()
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "hand.raised")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Privacy Permissions Audit")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            if auditService.isScanning {
                Button("Cancel") {
                    auditService.cancelScan()
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: { auditService.scanPermissions() }) {
                    Label("Scan", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var fdaStatusSection: some View {
        GroupBox {
            HStack {
                Image(systemName: fdaIcon)
                    .font(.title)
                    .foregroundStyle(fdaColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Disk Access")
                        .font(.headline)

                    Text(auditService.fdaStatus.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if auditService.fdaStatus == .denied || auditService.fdaStatus == .notRequested {
                    Button("Grant Access") {
                        auditService.requestFDA()
                    }
                    .buttonStyle(.bordered)
                } else if auditService.fdaStatus == .granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }
        }
    }

    private var controlsSection: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 200)

            Spacer()

            Text("\(auditService.appPermissions.count) apps scanned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(auditService.scanProgress)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyStateSection: some View {
        ContentUnavailableView(
            "No Permissions Found",
            systemImage: "hand.raised",
            description: Text("Click Scan to audit app permissions")
        )
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var permissionsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sortedApps, id: \.key) { bundleID, permissions in
                    if matchesFilter(bundleID: bundleID, permissions: permissions) {
                        AppPermissionsRow(
                            bundleIdentifier: bundleID,
                            permissions: permissions,
                            isExpanded: selectedApp == bundleID,
                            onTap: {
                                if selectedApp == bundleID {
                                    selectedApp = nil
                                } else {
                                    selectedApp = bundleID
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var fdaIcon: String {
        switch auditService.fdaStatus {
        case .granted: return "checkmark.shield.fill"
        case .denied, .notRequested: return "xmark.shield"
        case .requesting: return "arrow.clockwise"
        case .openSettings: return "gear"
        }
    }

    private var fdaColor: Color {
        switch auditService.fdaStatus {
        case .granted: return .green
        case .denied, .notRequested: return .red
        case .requesting: return .orange
        case .openSettings: return .orange
        }
    }

    private var sortedApps: [(key: String, value: [AppPermissionInfo])] {
        let allApps = Array(auditService.appPermissions).sorted { $0.value.count > $1.value.count }
        return allApps
    }

    private func matchesFilter(bundleID: String, permissions: [AppPermissionInfo]) -> Bool {
        // Search filter
        if !searchText.isEmpty {
            let appName = permissions.first?.appName ?? bundleID
            if !appName.localizedCaseInsensitiveContains(searchText) &&
               !bundleID.localizedCaseInsensitiveContains(searchText) {
                return false
            }
        }

        return true
    }
}

// MARK: - App Permissions Row

struct AppPermissionsRow: View {
    let bundleIdentifier: String
    let permissions: [AppPermissionInfo]
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // App icon
                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                            .resizable()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.title2)
                            .frame(width: 32, height: 32)
                    }

                    // App info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text("\(permissions.count) permission(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Permission summary
                    HStack(spacing: 8) {
                        let granted = permissions.filter { $0.status == .granted }.count
                        let denied = permissions.filter { $0.status == .missing }.count

                        if granted > 0 {
                            Label("\(granted)", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        if denied > 0 {
                            Label("\(denied)", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(permissions) { perm in
                        HStack {
                            Image(systemName: perm.permissionType.icon)
                                .foregroundStyle(Color(perm.permissionType.color))
                                .frame(width: 20)

                            Text(perm.permissionType.rawValue)
                                .font(.caption)

                            Spacer()

                            Image(systemName: perm.status.icon)
                                .foregroundStyle(Color(perm.status.color))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.05))
            }
        }
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var appName: String {
        permissions.first?.appName ?? bundleIdentifier
    }
}

// MARK: - Permission Category

enum PermissionCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case system = "System"
    case hardware = "Hardware"
    case personal = "Personal"
    case files = "Files"

    var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    PrivacyAuditView()
        .frame(width: 500, height: 600)
}