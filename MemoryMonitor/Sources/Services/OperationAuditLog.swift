//
//  OperationAuditLog.swift
//  Pulse
//
//  SQLite-free audit log using JSON file (like HistoricalMetricsService pattern).
//  Stored at ~/Library/Application Support/Pulse/audit_log.json
//  Records: timestamp, operation type, items affected, space freed, success/failure, user-initiated vs automated.
//  Supports filtering by date range, operation type, success status.
//  Exports to CSV.
//  Auto-truncates to 1000 most recent entries.
//

import Foundation
import Combine

// MARK: - Audit Log Entry

struct AuditLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let operationType: OperationType
    let itemsAffected: Int
    let spaceFreedBytes: UInt64
    let success: Bool
    let userInitiated: Bool
    let details: String?
    let errorMessage: String?

    var idValue: UUID { id }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var spaceFreedMB: Double { Double(spaceFreedBytes) / (1024 * 1024) }

    var formattedSpaceFreed: String {
        let mb = spaceFreedMB
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    var operationLabel: String {
        operationType.rawValue
    }

    var statusText: String {
        success ? "Success" : "Failed"
    }

    var initiatedText: String {
        userInitiated ? "User" : "Automated"
    }
}

// MARK: - Operation Type

enum OperationType: String, Codable, CaseIterable {
    case cleanup = "Cleanup"
    case scan = "Scan"
    case uninstall = "Uninstall"
    case duplicateRemoval = "Duplicate Removal"
    case installerCleanup = "Installer Cleanup"
    case cacheClear = "Cache Clear"
    case logPurge = "Log Purge"
    case memoryOptimize = "Memory Optimize"
    case diskCleanup = "Disk Cleanup"
    case permissionFix = "Permission Fix"
    case systemTweak = "System Tweak"
    case backup = "Backup"
    case restore = "Restore"
    case other = "Other"
}

// MARK: - Audit Log Filter

struct AuditLogFilter {
    var dateFrom: Date?
    var dateTo: Date?
    var operationType: OperationType?
    var successOnly: Bool?
    var userInitiatedOnly: Bool?

    static let all = AuditLogFilter()
}

// MARK: - OperationAuditLog

/// JSON-based audit log for tracking all cleanup and optimization operations.
class OperationAuditLog: ObservableObject {
    static let shared = OperationAuditLog()

    // MARK: - Published Properties

    @Published var entries: [AuditLogEntry] = []

    // MARK: - Configuration

    /// Maximum number of entries to keep
    var maxEntries: Int = 1000

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private lazy var logFileURL: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pulseDir = appSupport.appendingPathComponent("Pulse")
        try? fileManager.createDirectory(at: pulseDir, withIntermediateDirectories: true)
        return pulseDir.appendingPathComponent("audit_log.json")
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        loadEntries()
    }

    // MARK: - Public Methods

    /// Log a new operation
    func log(
        operation: OperationType,
        itemsAffected: Int = 0,
        spaceFreedBytes: UInt64 = 0,
        success: Bool = true,
        userInitiated: Bool = true,
        details: String? = nil,
        errorMessage: String? = nil
    ) {
        let entry = AuditLogEntry(
            id: UUID(),
            timestamp: Date(),
            operationType: operation,
            itemsAffected: itemsAffected,
            spaceFreedBytes: spaceFreedBytes,
            success: success,
            userInitiated: userInitiated,
            details: details,
            errorMessage: errorMessage
        )

        // Insert at beginning (most recent first)
        entries.insert(entry, at: 0)

        // Auto-truncate
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        // Save to disk asynchronously
        saveEntries()
    }

    /// Get filtered entries
    func getEntries(filter: AuditLogFilter = .all) -> [AuditLogEntry] {
        var filtered = entries

        if let dateFrom = filter.dateFrom {
            filtered = filtered.filter { $0.timestamp >= dateFrom }
        }
        if let dateTo = filter.dateTo {
            filtered = filtered.filter { $0.timestamp <= dateTo }
        }
        if let opType = filter.operationType {
            filtered = filtered.filter { $0.operationType == opType }
        }
        if let successOnly = filter.successOnly {
            filtered = filtered.filter { $0.success == successOnly }
        }
        if let userInitiatedOnly = filter.userInitiatedOnly {
            filtered = filtered.filter { $0.userInitiated == userInitiatedOnly }
        }

        return filtered
    }

    /// Export entries to CSV format
    func exportToCSV(filter: AuditLogFilter = .all) -> String {
        let filtered = getEntries(filter: filter)

        var csv = "Timestamp,Operation,Items Affected,Space Freed,Status,Initiated By,Details,Error\n"

        for entry in filtered {
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            let operation = entry.operationType.rawValue
            let items = "\(entry.itemsAffected)"
            let space = entry.formattedSpaceFreed
            let status = entry.success ? "Success" : "Failed"
            let initiated = entry.userInitiated ? "User" : "Automated"
            let details = entry.details?.replacingOccurrences(of: ",", with: ";") ?? ""
            let error = entry.errorMessage?.replacingOccurrences(of: ",", with: ";") ?? ""

            csv += "\(timestamp),\(operation),\(items),\(space),\(status),\(initiated),\"\(details)\",\"\(error)\"\n"
        }

        return csv
    }

    /// Clear all entries
    func clearAll() {
        entries.removeAll()
        saveEntries()
    }

    /// Get statistics summary
    func getStatistics() -> AuditStatistics {
        let totalOperations = entries.count
        let successfulOps = entries.filter { $0.success }.count
        let failedOps = entries.filter { !$0.success }.count
        let totalSpaceFreed = entries.reduce(UInt64(0)) { $0 + $1.spaceFreedBytes }
        let totalItemsAffected = entries.reduce(0) { $0 + $1.itemsAffected }

        let userOps = entries.filter { $0.userInitiated }.count
        let autoOps = entries.filter { !$0.userInitiated }.count

        // Today's stats
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let todayOps = entries.filter { $0.timestamp >= startOfToday }.count
        let todaySpaceFreed = entries.filter { $0.timestamp >= startOfToday }.reduce(UInt64(0)) { $0 + $1.spaceFreedBytes }

        return AuditStatistics(
            totalOperations: totalOperations,
            successfulOperations: successfulOps,
            failedOperations: failedOps,
            totalSpaceFreedBytes: totalSpaceFreed,
            totalItemsAffected: totalItemsAffected,
            userInitiatedOperations: userOps,
            automatedOperations: autoOps,
            todayOperations: todayOps,
            todaySpaceFreedBytes: todaySpaceFreed
        )
    }
}

// MARK: - Audit Statistics

struct AuditStatistics {
    let totalOperations: Int
    let successfulOperations: Int
    let failedOperations: Int
    let totalSpaceFreedBytes: UInt64
    let totalItemsAffected: Int
    let userInitiatedOperations: Int
    let automatedOperations: Int
    let todayOperations: Int
    let todaySpaceFreedBytes: UInt64

    var totalSpaceFreedMB: Double { Double(totalSpaceFreedBytes) / (1024 * 1024) }

    var formattedTotalSpaceFreed: String {
        let mb = totalSpaceFreedMB
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    var formattedTodaySpaceFreed: String {
        let mb = Double(todaySpaceFreedBytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations) * 100
    }
}

// MARK: - Persistence

extension OperationAuditLog {
    private func loadEntries() {
        do {
            if fileManager.fileExists(atPath: logFileURL.path) {
                let data = try Data(contentsOf: logFileURL)
                entries = try decoder.decode([AuditLogEntry].self, from: data)
                print("[OperationAuditLog] Loaded \(entries.count) entries from \(logFileURL.path)")
            }
        } catch {
            print("[OperationAuditLog] Failed to load entries from \(logFileURL.path): \(error)")
            entries = []
        }
    }

    private func saveEntries() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.encoder.encode(self.entries)
                try data.write(to: self.logFileURL, options: .atomic)
            } catch {
                print("[OperationAuditLog] Failed to save entries: \(error)")
            }
        }
    }
}
