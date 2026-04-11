//
//  CleanupPriority.swift
//  Pulse
//
//  Priority levels for cleanup items, used by ComprehensiveOptimizer
//  and other scanners to categorize how safe/recommended each cleanup is.
//

import Foundation

/// Priority levels for cleanup operations.
/// Higher priority = safer to delete, more recommended.
enum CleanupPriority: String, CaseIterable, Codable, Comparable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case optional = "Optional"

    var id: String { rawValue }

    /// Visual color for each priority level
    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "orange"
        case .optional: return "gray"
        }
    }

    /// SF Symbol representing the priority
    var icon: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        case .optional: return "questionmark.circle.fill"
        }
    }

    /// User-facing description of what this priority means
    var description: String {
        switch self {
        case .high:
            return "Safe to delete. Always recommended."
        case .medium:
            return "Safe but may cause minor slowdowns (e.g., rebuild caches)."
        case .low:
            return "Review before deleting. May contain items you want to keep."
        case .optional:
            return "User discretion. Large files or custom directories."
        }
    }

    /// Comparable: high > medium > low > optional
    static func < (lhs: CleanupPriority, rhs: CleanupPriority) -> Bool {
        lhs.sortOrder > rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .optional: return 3
        }
    }
}
