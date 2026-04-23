//
//  InstallerCleanupView.swift
//  Pulse
//
//  Shows old installers grouped by type/age, select to trash.
//

import SwiftUI

struct InstallerCleanupView: View {
    @StateObject private var service = InstallerCleanupService.shared
    @StateObject private var auditLog = OperationAuditLog.shared

    @State private var expandedGroups: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            headerSection
            Divider()

            if service.isScanning {
                scanningSection
            } else if service.installerFiles.isEmpty {
                emptyStateSection
            } else {
                resultsSection
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .alert("Move Installers to Trash?", isPresented: $showDeleteConfirmation) {
            Button("Move to Trash", role: .destructive) {
                performDeletion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(service.selectedForDeletion.count) installer files to the Trash. These are safe to delete as they are installation packages, not your personal files.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "shippingbox")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Installer Cleanup")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Spacer()

                if service.isScanning {
                    Button("Cancel") {
                        service.cancelScan()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: { service.startScan() }) {
                        Label("Scan", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Minimum age: \(service.minimumAgeDays) days")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Stepper(value: $service.minimumAgeDays, in: 1...90) {
                    Text("\(service.minimumAgeDays) days")
                        .font(DesignSystem.Typography.caption)
                }
                .frame(width: 120)
                .disabled(service.isScanning)
            }
        }
    }

    private var scanningSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(service.scanStatus)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(service.installerFiles.isEmpty && service.scanStatus != "Ready to scan"
                 ? "No old installers found"
                 : "Find Old Installers")
                .font(DesignSystem.Typography.headline)

            Text("Scans Downloads, Desktop, Documents, iCloud Drive, and Homebrew cache for old .dmg, .pkg, .zip, .sitx, .tgz files.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Summary bar
            summaryBar

            // Action buttons
            actionButtons

            Divider()

            // Results list
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(filteredGroups) { group in
                        installerGroupCard(group)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            statBadge(
                icon: "shippingbox",
                value: "\(service.installerFiles.count)",
                label: "Installers"
            )

            statBadge(
                icon: "arrow.uturn.left.circle",
                value: service.totalReclaimableBytes >= 1024 * 1024 * 1024
                    ? String(format: "%.1f GB", Double(service.totalReclaimableBytes) / (1024 * 1024 * 1024))
                    : String(format: "%.0f MB", Double(service.totalReclaimableBytes) / (1024 * 1024)),
                label: "Total Reclaimable"
            )

            if !service.selectedForDeletion.isEmpty {
                Spacer()
                Text("\(service.selectedForDeletion.count) selected")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Button(action: { service.selectAll() }) {
                Label("Select All", systemImage: "checkmark.circle")
            }
            .buttonStyle(.bordered)

            Button(action: { service.deselectAll() }) {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .disabled(service.selectedForDeletion.isEmpty)

            Spacer()

            Button(action: { showDeleteConfirmation = true }) {
                Label("Move \(service.selectedForDeletion.count) to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(service.selectedForDeletion.isEmpty)
        }
    }

    private func installerGroupCard(_ group: InstallerGroup) -> some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                if expandedGroups.contains(group.id) {
                    expandedGroups.remove(group.id)
                } else {
                    expandedGroups.insert(group.id)
                }
            }) {
                HStack {
                    Image(systemName: group.type.icon)
                        .foregroundStyle(group.type.colorValue)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(group.type.rawValue) — \(group.ageCategory.rawValue)")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.medium)

                        Text("\(group.files.count) files · \(group.formattedTotalSize)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Select/deselect group button
                    let allSelected = group.files.allSatisfy { service.selectedForDeletion.contains($0.id) }
                    Button(action: {
                        if allSelected {
                            for file in group.files {
                                service.selectedForDeletion.remove(file.id)
                            }
                        } else {
                            for file in group.files {
                                service.selectedForDeletion.insert(file.id)
                            }
                        }
                    }) {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(allSelected ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: expandedGroups.contains(group.id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DesignSystem.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded file list
            if expandedGroups.contains(group.id) {
                VStack(spacing: 0) {
                    Divider()

                    ForEach(group.files) { file in
                        installerFileRow(file)
                    }
                }
                .background(DesignSystem.Colors.hoverBackground)
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }

    private func installerFileRow(_ file: InstallerFile) -> some View {
        let isSelected = service.selectedForDeletion.contains(file.id)

        return HStack(spacing: DesignSystem.Spacing.md) {
            // Checkbox
            Button(action: {
                if isSelected {
                    service.selectedForDeletion.remove(file.id)
                } else {
                    service.selectedForDeletion.insert(file.id)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(DesignSystem.Typography.body)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(file.parentDirectory)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(file.formattedSize)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(file.formattedAge)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(file.formattedDate)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Filtered Groups

    private var filteredGroups: [InstallerGroup] {
        if searchText.isEmpty {
            return service.groupedFiles
        }
        return service.groupedFiles.filter { group in
            group.files.contains { file in
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func performDeletion() {
        let result = service.deleteSelectedFiles()

        auditLog.log(
            operation: .installerCleanup,
            itemsAffected: result.success,
            spaceFreedBytes: result.bytesFreed,
            success: result.failed == 0,
            userInitiated: true,
            details: "Trashed \(result.success) installer files",
            errorMessage: result.failed > 0 ? "\(result.failed) files failed to delete" : nil
        )
    }
}
