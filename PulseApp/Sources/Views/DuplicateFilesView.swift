//
//  DuplicateFilesView.swift
//  Pulse
//
//  Shows duplicate file groups, lets user select which to keep, shows reclaimable space.
//

import SwiftUI

struct DuplicateFilesView: View {
    @StateObject private var scanner = DuplicateFileScanner.shared
    @StateObject private var auditLog = OperationAuditLog.shared

    @State private var selectedDirectories: [String] = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Desktop"
    ]
    @State private var keepStrategy: KeepStrategy = .oldest
    @State private var expandedGroups: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    enum KeepStrategy {
        case oldest
        case newest

        var label: String {
            switch self {
            case .oldest: return "Keep Oldest"
            case .newest: return "Keep Newest"
            }
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            headerSection
            Divider()

            if scanner.isScanning {
                scanningSection
            } else if scanner.duplicateGroups.isEmpty {
                emptyStateSection
            } else {
                resultsSection
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .alert("Delete Selected Duplicates?", isPresented: $showDeleteConfirmation) {
            Button("Move to Trash", role: .destructive) {
                performDeletion()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move \(scanner.selectedForDeletion.count) duplicate files to the Trash. You can restore them from Trash if needed.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.purple)

                Text("Duplicate File Scanner")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Spacer()

                if scanner.isScanning {
                    Button("Cancel") {
                        scanner.cancelScan()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: startScan) {
                        Label("Scan", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scanner.isScanning)
                }
            }

            // Directory selection
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text("Scan directories:")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Strategy", selection: $keepStrategy) {
                    Text(KeepStrategy.oldest.label).tag(KeepStrategy.oldest)
                    Text(KeepStrategy.newest.label).tag(KeepStrategy.newest)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .disabled(scanner.isScanning)
            }
        }
    }

    private var scanningSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(scanner.scanProgress.statusText)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text(scanner.scanProgress == .idle ? "No duplicates found" : "Scan Complete")
                .font(DesignSystem.Typography.headline)

            Text("Add directories to scan and click 'Scan' to find duplicate files.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
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
                        duplicateGroupCard(group)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            statBadge(
                icon: "doc.badge.gearshape",
                value: "\(scanner.duplicateGroups.count)",
                label: "Groups"
            )

            statBadge(
                icon: "doc.on.doc",
                value: "\(scanner.duplicateGroups.reduce(0) { $0 + $1.duplicateCount })",
                label: "Duplicates"
            )

            statBadge(
                icon: "arrow.uturn.left.circle",
                value: scanner.duplicateGroups.reduce(0.0) { $0 + $1.reclaimableMB } >= 1024
                    ? String(format: "%.1f GB", scanner.duplicateGroups.reduce(0.0) { $0 + $1.reclaimableMB } / 1024)
                    : String(format: "%.0f MB", scanner.duplicateGroups.reduce(0.0) { $0 + $1.reclaimableMB }),
                label: "Reclaimable"
            )

            if !scanner.selectedForDeletion.isEmpty {
                Spacer()
                Text("\(scanner.selectedForDeletion.count) selected")
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
            Button(action: {
                switch keepStrategy {
                case .oldest: scanner.autoSelectOldestKeep()
                case .newest: scanner.autoSelectNewestKeep()
                }
            }) {
                Label("Auto-select (\(keepStrategy.label))", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)

            Button("Clear Selection") {
                scanner.selectedForDeletion = []
            }
            .buttonStyle(.bordered)
            .disabled(scanner.selectedForDeletion.isEmpty)

            Spacer()

            Button(action: { showDeleteConfirmation = true }) {
                Label("Move Selected to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(scanner.selectedForDeletion.isEmpty)
        }
    }

    private func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        VStack(spacing: 0) {
            // Header (clickable to expand/collapse)
            Button(action: {
                if expandedGroups.contains(group.id) {
                    expandedGroups.remove(group.id)
                } else {
                    expandedGroups.insert(group.id)
                }
            }) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.purple)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.files.first?.name ?? "Unknown")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text("\(group.files.count) copies · \(group.formattedFileSize) each")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("+\(group.formattedReclaimable)")
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)

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

                    let sortedFiles = group.files.sorted { $0.modificationDate < $1.modificationDate }
                    ForEach(sortedFiles) { file in
                        duplicateFileRow(file, in: group)
                    }
                }
                .background(DesignSystem.Colors.hoverBackground)
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }

    private func duplicateFileRow(_ file: DuplicateFile, in group: DuplicateGroup) -> some View {
        let isSelected = scanner.selectedForDeletion.contains(file.id)
        let isProtected = DuplicateFileScanner.isPathProtected(file.path)
        let isKeepCandidate = isKeepCandidate(file, in: group)

        return HStack(spacing: DesignSystem.Spacing.md) {
            // Selection checkbox
            Button(action: {
                if !isProtected {
                    if isSelected {
                        scanner.selectedForDeletion.remove(file.id)
                    } else {
                        scanner.selectedForDeletion.insert(file.id)
                    }
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isProtected ? .gray : isSelected ? .blue : .secondary)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(isProtected)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(file.name)
                        .font(DesignSystem.Typography.body)
                        .lineLimit(1)

                    if isKeepCandidate {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

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
                    Text(file.formattedDate)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isProtected {
                Text("Protected")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .opacity(isProtected ? 0.6 : 1.0)
    }

    private func isKeepCandidate(_ file: DuplicateFile, in group: DuplicateGroup) -> Bool {
        let sorted = group.files.sorted {
            switch keepStrategy {
            case .oldest: return $0.modificationDate < $1.modificationDate
            case .newest: return $0.modificationDate > $1.modificationDate
            }
        }
        return sorted.first?.id == file.id
    }

    // MARK: - Filtered Groups

    private var filteredGroups: [DuplicateGroup] {
        if searchText.isEmpty {
            return scanner.duplicateGroups
        }
        return scanner.duplicateGroups.filter { group in
            group.files.contains { file in
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func startScan() {
        scanner.startScan(directories: selectedDirectories)
    }

    private func performDeletion() {
        let result = scanner.deleteSelectedFiles()

        auditLog.log(
            operation: .duplicateRemoval,
            itemsAffected: result.success,
            spaceFreedBytes: result.bytesFreed,
            success: result.failed == 0,
            userInitiated: true,
            details: "Deleted \(result.success) duplicate files",
            errorMessage: result.failed > 0 ? "\(result.failed) files failed to delete" : nil
        )
    }
}
