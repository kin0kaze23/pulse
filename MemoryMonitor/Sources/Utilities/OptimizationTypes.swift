//
//  OptimizationTypes.swift
//  Pulse
//
//  Shared types for optimization operations
//  Consolidates duplicate OptimizeResult definitions from MemoryOptimizer and ComprehensiveOptimizer
//

import Foundation

// MARK: - Optimize Result

/// Result of an optimization operation
struct OptimizeResult {
    let steps: [Step]
    let skipped: [SkippedItem]
    let totalFreedMB: Double
    let timestamp: Date
    
    /// Create with optional skipped items (for simple optimizations)
    init(steps: [Step], skipped: [SkippedItem] = [], totalFreedMB: Double, timestamp: Date = Date()) {
        self.steps = steps
        self.skipped = skipped
        self.totalFreedMB = totalFreedMB
        self.timestamp = timestamp
    }
    
    // MARK: - Computed Properties
    
    var summary: String {
        let successCount = steps.filter(\.success).count
        if totalFreedMB > 1024 {
            return "\(successCount) actions · \(String(format: "%.1f GB", totalFreedMB / 1024)) freed"
        }
        return "\(successCount) actions · \(String(format: "%.0f MB", totalFreedMB)) freed"
    }
    
    var detailLines: [String] {
        steps.map { step in
            let prefix = step.success ? "✓" : "✗"
            let size = step.freedMB > 1024
                ? String(format: "%.1f GB", step.freedMB / 1024)
                : String(format: "%.0f MB", step.freedMB)
            return "\(prefix) \(step.name): \(size)"
        }
    }
    
    var successCount: Int {
        steps.filter(\.success).count
    }
    
    var failureCount: Int {
        steps.filter { !$0.success }.count
    }
    
    // MARK: - Step
    
    struct Step {
        let name: String
        let freedMB: Double
        let success: Bool
        let category: Category?
        let priority: CleanupPriority?
        
        init(name: String, freedMB: Double, success: Bool, category: Category? = nil, priority: CleanupPriority? = nil) {
            self.name = name
            self.freedMB = freedMB
            self.success = success
            self.category = category
            self.priority = priority
        }
    }
    
    // MARK: - Skipped Item
    
    struct SkippedItem: Identifiable {
        let id = UUID()
        let name: String
        let reason: String
        let sizeMB: Double
    }
    
    // MARK: - Category
    
    enum Category: String, CaseIterable {
        case developer = "Developer"
        case browser = "Browser"
        case application = "Applications"
        case system = "System"
        case memory = "Memory"
        case disk = "Disk"
        case logs = "Logs"
        
        var icon: String {
            switch self {
            case .developer: return "chevron.left.forwardslash.chevron.right"
            case .browser: return "globe"
            case .application: return "app.fill"
            case .system: return "gearshape.fill"
            case .memory: return "memorychip"
            case .disk: return "externaldrive.fill"
            case .logs: return "doc.text.fill"
            }
        }
        
        var color: String {
            switch self {
            case .developer: return "purple"
            case .browser: return "blue"
            case .application: return "cyan"
            case .system: return "green"
            case .memory: return "orange"
            case .disk: return "red"
            case .logs: return "yellow"
            }
        }
    }
}

// MARK: - Size Formatting Extensions

extension Double {
    /// Format as size string (MB or GB)
    var sizeText: String {
        if self > 1024 {
            return String(format: "%.1f GB", self / 1024)
        }
        return String(format: "%.0f MB", self)
    }
}