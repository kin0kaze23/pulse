//
//  AuditLogView.swift
//  Pulse
//
//  Shows audit history with filters and CSV export button.
//

import SwiftUI
import AppKit

struct AuditLogView: View {
    @StateObject private var auditLog = OperationAuditLog.shared

    @State private var filter: AuditLogFilter = .all
    @State private var showClearConfirmation = false
    @State private var searchText = ""
    @State private var showExportSuccess = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            headerSection
            Divider()

            if auditLog.entries.isEmpty {
                emptyStateSection
            } else {
                resultsSection
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .alert("Clear Audit Log?", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                auditLog.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all audit log entries. This cannot be undone.")
        }
        .overlay {
            if showExportSuccess {
                SimpleToastView(
                    message: "CSV exported to clipboard",
                    icon: "checkmark.circle.fill",
                    isPresented: $showExportSuccess
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, DesignSystem.Spacing.lg)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Operation Audit Log")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                Spacer()

                // Export button
                Button(action: exportCSV) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(auditLog.entries.isEmpty)

                // Clear button
                Button(action: { showClearConfirmation = true }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(auditLog.entries.isEmpty)
            }

            // Filters row
            filtersRow

            // Statistics
            if !auditLog.entries.isEmpty {
                statisticsRow
            }
        }
    }

    private var filtersRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.caption)
            }
            .padding(DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
            .frame(width: 150)

            // Operation type filter
            Picker("Type", selection: Binding(
                get: { filter.operationType },
                set: { filter.operationType = $0 }
            )) {
                Text("All Types").tag(nil as OperationType?)
                ForEach(OperationType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type as OperationType?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            // Status filter
            Picker("Status", selection: Binding(
                get: { filter.successOnly },
                set: { filter.successOnly = $0 }
            )) {
                Text("All").tag(nil as Bool?)
                Text("Success").tag(true as Bool?)
                Text("Failed").tag(false as Bool?)
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            // Initiated filter
            Picker("By", selection: Binding(
                get: { filter.userInitiatedOnly },
                set: { filter.userInitiatedOnly = $0 }
            )) {
                Text("All").tag(nil as Bool?)
                Text("User").tag(true as Bool?)
                Text("Auto").tag(false as Bool?)
            }
            .pickerStyle(.menu)
            .frame(width: 80)

            Spacer()

            // Reset filters
            Button(action: { filter = .all; searchText = "" }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .help("Reset filters")
        }
    }

    private var statisticsRow: some View {
        let stats = auditLog.getStatistics()
        return HStack(spacing: DesignSystem.Spacing.lg) {
            statBadge(
                icon: "list.clipboard",
                value: "\(stats.totalOperations)",
                label: "Total Operations"
            )

            statBadge(
                icon: "checkmark.circle",
                value: "\(stats.successfulOperations)",
                label: "Successful"
            )

            statBadge(
                icon: "xmark.circle",
                value: "\(stats.failedOperations)",
                label: "Failed"
            )

            statBadge(
                icon: "arrow.uturn.left.circle",
                value: stats.formattedTotalSpaceFreed,
                label: "Total Freed"
            )

            Spacer()

            Text(String(format: "%.0f%% success rate", stats.successRate))
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
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

    private var emptyStateSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No audit entries")
                .font(DesignSystem.Typography.headline)

            Text("Operations like cleanup, scans, and duplicate removal will be logged here.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Table header
            tableHeader

            Divider()

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        auditEntryRow(entry)
                        Divider()
                    }
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text("Time")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            Text("Operation")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            Text("Items")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .center)

            Text("Space")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            Text("Status")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .center)

            Text("By")
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .center)

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private func auditEntryRow(_ entry: AuditLogEntry) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(entry.formattedTimestamp)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: entry.operationType.icon)
                    .font(.caption2)
                Text(entry.operationType.rawValue)
                    .font(DesignSystem.Typography.caption)
            }
            .frame(width: 120, alignment: .leading)

            Text("\(entry.itemsAffected)")
                .font(DesignSystem.Typography.caption)
                .frame(width: 50, alignment: .center)

            Text(entry.formattedSpaceFreed)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(entry.spaceFreedBytes > 0 ? .green : .secondary)
                .frame(width: 70, alignment: .trailing)

            StatusBadge(success: entry.success)
                .frame(width: 60, alignment: .center)

            Text(entry.initiatedText)
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .center)

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(entry.hoverBackground)
    }

    private var filteredEntries: [AuditLogEntry] {
        var entries = auditLog.getEntries(filter: filter)

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.operationType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                (entry.details?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.errorMessage?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return entries
    }

    // MARK: - Actions

    private func exportCSV() {
        let csv = auditLog.exportToCSV(filter: filter)

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(csv, forType: .string)

        showExportSuccess = true
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let success: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(success ? .green : .red)
            Text(success ? "OK" : "Fail")
                .font(DesignSystem.Typography.caption2)
                .foregroundStyle(success ? .green : .red)
        }
    }
}

// MARK: - Hover Background

extension AuditLogEntry {
    var hoverBackground: AnyShapeStyle {
        AnyShapeStyle(DesignSystem.Colors.cardBackground)
    }
}

// MARK: - Operation Type Icon Extension

extension OperationType {
    var icon: String {
        switch self {
        case .cleanup: return "broom"
        case .scan: return "magnifyingglass"
        case .uninstall: return "app.badge.xmark"
        case .duplicateRemoval: return "doc.badge.plus"
        case .installerCleanup: return "shippingbox"
        case .cacheClear: return "trash.circle"
        case .logPurge: return "doc.plaintext"
        case .memoryOptimize: return "memorychip"
        case .diskCleanup: return "externaldrive"
        case .permissionFix: return "lock.shield"
        case .systemTweak: return "gearshape"
        case .backup: return "externaldrive.badge.timemachine"
        case .restore: return "arrow.uturn.backward.circle"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Simple Toast View

struct SimpleToastView: View {
    let message: String
    let icon: String
    @Binding var isPresented: Bool
    @State private var workItem: DispatchWorkItem?

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(message)
                .font(DesignSystem.Typography.caption)
        }
        .padding(DesignSystem.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
        .onAppear {
            workItem?.cancel()
            let task = DispatchWorkItem {
                withAnimation {
                    isPresented = false
                }
            }
            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: task)
        }
    }
}
