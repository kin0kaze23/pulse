//
//  NodeDelegator.swift
//  Pulse
//
//  Thin adapter that delegates Node.js cache cleanup to PulseCore NodeEngine.
//  No new business logic, no AppSettings dependency, no UI concerns.
//

import Foundation
import PulseCore

/// Delegates Node.js cache scan and cleanup to PulseCore NodeEngine.
/// Maps between app-facing CleanupPlan types and PulseCore types.
struct NodeDelegator {
    private let engine: CleanupEngine
    private let nodeEngine: NodeEngine

    init(
        engine: CleanupEngine = CleanupEngine(),
        nodeEngine: NodeEngine = NodeEngine()
    ) {
        self.engine = engine
        self.nodeEngine = nodeEngine
    }

    // MARK: - Scan

    /// Scan Node.js cache profiles via PulseCore. Returns mapped CleanupItems.
    func scan(excludedPaths: [String]) -> [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        let corePlan = nodeEngine.scan()
        return corePlan.items.map { mapItem($0) }
    }

    // MARK: - Apply

    /// Apply Node.js cache cleanup via PulseCore. Returns the MB freed.
    /// Node items use .file action — CleanupEngine handles file deletion.
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
            action: .file,
            profile: .node
        )
        let plan = PulseCore.CleanupPlan(items: [coreItem], totalSizeMB: item.sizeMB)
        let config = CleanupConfig(profiles: [.node], excludedPaths: excludedPaths)
        let result = engine.apply(plan: plan, config: config)
        return result.totalFreedMB
    }

    // MARK: - Type Mapping

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
            action: core.action,
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
