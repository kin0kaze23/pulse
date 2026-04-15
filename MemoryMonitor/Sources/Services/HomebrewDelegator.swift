//
//  HomebrewDelegator.swift
//  Pulse
//
//  Thin adapter that delegates Homebrew cleanup to PulseCore HomebrewEngine.
//  No new business logic, no AppSettings dependency, no UI concerns.
//

import Foundation
import PulseCore

/// Delegates Homebrew scan and cleanup to PulseCore HomebrewEngine.
/// Maps between app-facing CleanupPlan types and PulseCore types.
struct HomebrewDelegator {
    private let engine: HomebrewEngine

    init(engine: HomebrewEngine = HomebrewEngine()) {
        self.engine = engine
    }

    // MARK: - Scan

    /// Scan Homebrew profiles via PulseCore. Returns mapped CleanupItems.
    func scan() -> [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        let corePlan = engine.scan()
        return corePlan.items.map { mapItem($0) }
    }

    // MARK: - Apply

    /// Apply Homebrew cleanup via PulseCore. Returns the CleanupResult.
    func apply() -> PulseCore.CleanupResult {
        engine.apply()
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
            action: core.action
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

    private func mapPriorityToApp(_ priority: PulseCore.CleanupPriority) -> Pulse.CleanupPriority {
        switch priority {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .optional: return .optional
        }
    }
}
