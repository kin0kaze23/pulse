//
//  XcodeDelegator.swift
//  Pulse
//
//  Thin adapter that delegates Xcode cleanup to PulseCore.
//  No new business logic, no AppSettings dependency, no UI concerns.
//

import Foundation
import PulseCore

/// Delegates Xcode scan and apply to PulseCore CleanupEngine.
/// Maps between app-facing CleanupPlan types and PulseCore types.
struct XcodeDelegator {
    private let engine: CleanupEngine

    init(engine: CleanupEngine = CleanupEngine()) {
        self.engine = engine
    }

    // MARK: - Scan

    /// Scan Xcode profiles via PulseCore. Returns mapped CleanupItems.
    func scan(excludedPaths: [String]) -> [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        let config = CleanupConfig(profiles: [.xcode], excludedPaths: excludedPaths)
        let corePlan = engine.scan(config: config)
        return corePlan.items.map { mapItem($0) }
    }

    // MARK: - Apply

    /// Apply Xcode cleanup via PulseCore. Returns the MB freed.
    func apply(item: ComprehensiveOptimizer.CleanupPlan.CleanupItem, excludedPaths: [String]) -> Double {
        let coreItem = PulseCore.CleanupPlan.CleanupItem(
            name: item.name,
            sizeMB: item.sizeMB,
            category: mapCategoryToCore(item.category),
            path: item.path,
            isDestructive: item.isDestructive,
            requiresAppClosed: item.requiresAppClosed,
            appName: item.appName,
            warningMessage: item.warningMessage,
            priority: mapPriorityToCore(item.priority),
            profile: .xcode
        )
        let plan = PulseCore.CleanupPlan(items: [coreItem], totalSizeMB: item.sizeMB)
        let config = CleanupConfig(profiles: [.xcode], excludedPaths: excludedPaths)
        let result = engine.apply(plan: plan, config: config)
        return result.totalFreedMB
    }

    // MARK: - Type Mapping (PulseCore -> App)

    private func mapItem(_ core: PulseCore.CleanupPlan.CleanupItem) -> ComprehensiveOptimizer.CleanupPlan.CleanupItem {
        .init(
            name: core.name,
            sizeMB: core.sizeMB,
            category: mapCategoryToApp(core.category),
            path: core.path,
            isDestructive: core.isDestructive,
            requiresAppClosed: core.requiresAppClosed,
            appName: core.appName,
            warningMessage: core.warningMessage,
            priority: mapPriorityToApp(core.priority),
            profile: core.profile
        )
    }

    private func mapCategoryToApp(_ category: PulseCore.CleanupCategory) -> OptimizeResult.Category {
        switch category {
        case .developer: return .developer
        case .browser: return .browser
        case .application: return .application
        case .system: return .system
        case .logs: return .logs
        }
    }

    private func mapCategoryToCore(_ category: OptimizeResult.Category) -> PulseCore.CleanupCategory {
        switch category {
        case .developer: return .developer
        case .browser: return .browser
        case .application: return .application
        case .system: return .system
        case .logs: return .logs
        case .memory: return .system
        case .disk: return .system
        }
    }

    private func mapPriorityToApp(_ priority: PulseCore.CleanupPriority) -> CleanupPriority {
        switch priority {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .optional: return .optional
        }
    }

    private func mapPriorityToCore(_ priority: CleanupPriority) -> PulseCore.CleanupPriority {
        switch priority {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .optional: return .optional
        }
    }
}
