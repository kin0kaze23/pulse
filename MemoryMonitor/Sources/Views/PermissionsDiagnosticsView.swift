//
//  PermissionsDiagnosticsView.swift
//  Pulse
//
//  Permissions diagnostics UI - shows permission status and how to enable
//

import SwiftUI

/// Permissions diagnostics view showing status of all Pulse permissions
struct PermissionsDiagnosticsView: View {
    @ObservedObject var service = PermissionsService.shared
    @State private var selectedPermission: PermissionInfo?
    @State private var showChangedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            headerSection
                .staggeredEntrance(delay: 0)

            // Permission list
            permissionList
                .staggeredEntrance(delay: 0.1)

            // Help text
            helpSection
                .staggeredEntrance(delay: 0.15)

            // Toast notification for permission changes
            if showChangedToast {
                permissionChangedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .onAppear {
            service.checkAllPermissions()
        }
        .onChange(of: service.permissionsChanged) { _, changed in
            if changed {
                showChangedToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showChangedToast = false
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status icon
            ZStack {
                Circle()
                    .fill(service.hasCriticalPermissionsMissing ? Color.orange.opacity(0.12) : Color.green.opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Image(systemName: service.hasCriticalPermissionsMissing ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(service.hasCriticalPermissionsMissing ? .orange : .green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                
                if service.isChecking {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Checking permissions...")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(service.permissionSummary)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(service.hasCriticalPermissionsMissing ? .orange : .secondary)
                }
            }
            
            Spacer()
            
            // Refresh button
            Button {
                service.checkAllPermissions()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(Circle().fill(Color.primary.opacity(0.06)))
            .disabled(service.isChecking)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Permission List
    
    private var permissionList: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(service.permissions) { permission in
                permissionRow(permission: permission)
            }
        }
    }
    
    private func permissionRow(permission: PermissionInfo) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header row
            HStack(spacing: DesignSystem.Spacing.md) {
                // Status icon
                Image(systemName: permission.status.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(permission.status.color))
                    .frame(width: 24)
                
                // Permission name
                Text(permission.type.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status badge
                Text(permission.status.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(permission.status.color).opacity(0.12))
                    )
                    .foregroundColor(Color(permission.status.color))

                // Enable button (if missing or verification pending)
                if permission.isMissing || permission.status == .verificationPending {
                    Button {
                        service.openSettings(for: permission.type)
                    } label: {
                        Text(permission.status == .verificationPending ? "Verify" : "Enable")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.gradient)
                    )
                    .foregroundColor(.white)
                }
            }

            // Details (expanded)
            if selectedPermission?.id == permission.id {
                permissionDetails(permission: permission)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(permissionRowBackground(permission))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                        .stroke(permissionRowBorder(permission), lineWidth: 1)
                )
        )
        .onTapGesture {
            togglePermissionSelection(permission)
        }
    }

    private func permissionRowBackground(_ permission: PermissionInfo) -> Color {
        if permission.isMissing || permission.status == .verificationPending {
            return Color.orange.opacity(0.05)
        }
        return Color(nsColor: .textBackgroundColor).opacity(0.3)
    }

    private func permissionRowBorder(_ permission: PermissionInfo) -> Color {
        if permission.isMissing || permission.status == .verificationPending {
            return Color.orange.opacity(0.2)
        }
        return Color.clear
    }

    private func togglePermissionSelection(_ permission: PermissionInfo) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedPermission?.id == permission.id {
                selectedPermission = nil
            } else {
                selectedPermission = permission
            }
        }
    }
    
    private func permissionDetails(permission: PermissionInfo) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Divider()
                .padding(.vertical, DesignSystem.Spacing.sm)
            
            // Why needed
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                    Text("Why Pulse needs this")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Text(permission.whyNeeded)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
            }
            
            // Affected features
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.purple)
                    Text("Affected features")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                affectedFeaturesList(permission: permission)
            }
            
            // How to enable
            if permission.isMissing || permission.status == .verificationPending {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                        Text(permission.status == .verificationPending ? "How to verify" : "How to enable")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    if permission.status == .verificationPending {
                        Text("Permission checks returned mixed results. Please visit System Settings to verify Pulse has Full Disk Access enabled.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.primary)
                            .lineSpacing(2)
                    } else {
                        Text(permission.howToEnable)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.primary)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    private func affectedFeaturesList(permission: PermissionInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(permission.affectedFeatures, id: \.self) { feature in
                HStack(spacing: 6) {
                    let iconName = permission.isGranted ? "checkmark" : (permission.status == .verificationPending ? "exclamationmark" : "xmark")
                    let colorName = permission.isGranted ? "green" : (permission.status == .verificationPending ? "yellow" : "orange")

                    Image(systemName: iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(colorName))

                    Text(feature)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // MARK: - Permission Changed Toast

    private var permissionChangedToast: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Icon based on whether permission was granted or revoked
            Image(systemName: service.recentChange?.wasGranted == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(service.recentChange?.wasGranted == true ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                // Specific message about what changed
                if let change = service.recentChange {
                    Text("\(change.type.rawValue) \(change.wasGranted ? "granted" : "revoked")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(change.wasGranted ? "Feature limitations lifted" : "Some features may now be limited")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("Permission status updated")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Changes detected — some features may now be available")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(DesignSystem.Radius.medium)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Help Section

    private var helpSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.yellow)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy First")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Pulse only requests permissions it actually needs. All permission checks happen locally on your Mac.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(Color.yellow.opacity(0.08))
        )
    }
}

// MARK: - Preview

#Preview {
    PermissionsDiagnosticsView()
        .frame(width: 500)
}
