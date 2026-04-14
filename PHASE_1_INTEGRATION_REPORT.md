# Phase 1 Integration Report: Xcode Delegation to PulseCore

**Date:** 2026-04-14
**Branch:** phase0-hardening
**Scope:** Wire ComprehensiveOptimizer to delegate Xcode cleanup only to PulseCore

---

## Summary

ComprehensiveOptimizer now delegates Xcode profile scan and apply operations to PulseCore's CleanupEngine via a thin `XcodeDelegator` adapter. All other cleanup profiles (Homebrew, browser caches, system caches, application caches, logs, trash, Docker, etc.) remain handled by ComprehensiveOptimizer's existing logic.

---

## Files Changed

### New files (2)
| File | Purpose |
|------|---------|
| `MemoryMonitor/Sources/Services/XcodeDelegator.swift` | Thin adapter struct. Maps between app `CleanupPlan.CleanupItem` and `PulseCore.CleanupPlan.CleanupItem`. Delegates scan to `CleanupEngine.scan(config:)` and apply to `CleanupEngine.apply(plan:, config:)`. |
| `Tests/PulseCoreTests/XcodeDelegatorTests.swift` | 7 integration tests: scan returns non-negative plan, empty profiles return empty plan, items have correct category, apply deletes real directory, apply skips nonexistent/protected/excluded paths. |

### Modified files (1)
| File | Change |
|------|--------|
| `MemoryMonitor/Sources/Services/ComprehensiveOptimizer.swift` | Added `import PulseCore`. Added `xcodeDelegator: XcodeDelegator` property. Replaced 68 lines of inline Xcode scanning in `scanDeveloperCaches()` with call to `scanXcodeViaPulseCore()`. Added `isXcodeProfileItem()` helper. Updated `executeCleanupItem()` to route Xcode items through delegator. |

**Net diff:** +42 / -69 lines in ComprehensiveOptimizer (net reduction of 27 lines)

---

## Commands Run

```bash
swift build          # Build - PASS
swift test           # Full suite - pre-existing failures only (4)
swift test --filter PulseCoreTests  # 26 tests, 0 failures - PASS
swift test --filter XcodeDelegator  # 7 tests, 0 failures - PASS
```

---

## Pre-existing Test Failures (Unrelated)

These failures existed before this change and are not caused by the adapter:

| Test | Issue |
|------|-------|
| `AppUninstallerTests.testPathSafetyAllowsLibraryPaths` | Path safety assertion mismatch |
| `DirectorySizeUtilityTests.testDirectorySizeGB` | Floating point accuracy (0.014 GB delta) |
| `OperationTypeTests.testAllCases` | Case count mismatch (13 vs 14) |
| `SmartTriggerMonitorTests.testBatteryThreshold_syncsToAppSettings` | NSInternalInconsistencyException in test harness |

---

## Adapter Design

### What the adapter does
1. **Scan path**: `ComprehensiveOptimizer.scanDeveloperCaches()` calls `xcodeDelegator.scan(excludedPaths:)` which calls `CleanupEngine.scan(config:)` with `CleanupConfig(profiles: [.xcode])`
2. **Apply path**: `ComprehensiveOptimizer.executeCleanupItem()` detects Xcode profile items by path match and calls `xcodeDelegator.apply(item:, excludedPaths:)` which calls `CleanupEngine.apply(plan:, config:)`
3. **Type mapping**: `XcodeDelegator` maps `PulseCore.CleanupCategory` <-> `OptimizeResult.Category` and `PulseCore.CleanupPriority` <-> `Pulse.CleanupPriority`
4. **Settings respect**: App-level toggles (`cleanXcodeDerivedData`, `cleanXcodeDeviceSupport`) are applied as post-scan filters on PulseCore results

### What the adapter does NOT do
- No new business logic in ComprehensiveOptimizer
- No new singleton-style dependencies in PulseCore
- No AppSettings dependency inside PulseCore
- No ObservableObject/@Published logic inside PulseCore
- No UI concerns added to PulseCore
- No extraction of Homebrew or other profiles
- No changes to monitoring, security, automation, or CLI systems

---

## Key Difference: App vs PulseCore Xcode Handling

| Aspect | Before (ComprehensiveOptimizer) | After (PulseCore via Delegator) |
|--------|-------------------------------|--------------------------------|
| Size measurement | `DirectorySizeUtility.quickDirectorySizeMB` (FileManager-based) | `DirectoryScanner.directorySizeMB` (du -sk based) |
| Deletion method | `FileManager.trashItem()` (goes to Trash) | `FileManager.default.removeItem()` (permanent delete) |
| Running app check | Checks `isXcodeRunning()` before scan | No running app check in PulseCore |
| Safety validation | `isPathSafeToDelete()` inline | `SafetyValidator` in PulseCore |
| UX delays | `Thread.sleep()` for progress animation | None (pure execution) |

**Note:** The deletion behavior change (Trash vs permanent) is a real difference. The app's `cleanPath()` sends files to Trash; PulseCore's `executeDelete()` permanently deletes. This is acceptable for now since PulseCore paths are caches that regenerate. If Trash behavior is required for Xcode cleanup, it should be added to PulseCore as a separate concern.

---

## Unresolved Issues

1. **Trash vs permanent deletion**: PulseCore permanently deletes; app sends to Trash. This is a behavioral change for Xcode cleanup. Recommend adding Trash support to PulseCore before expanding to Homebrew.
2. **Running app check**: The app checks `isXcodeRunning()` before showing Xcode DerivedData items; PulseCore does not. The delegator preserves the running-app warning in the scan phase (via `mapItem`), but the scan itself runs regardless. The `executeCleanupItem` path no longer blocks on Xcode running status for delegated items.
3. **Thread.sleep removal**: The Xcode scan path no longer has `Thread.sleep()` delays. This is intentional (requirement 4) and is the correct behavior — PulseCore is a pure engine, not a UI coordinator.

---

## Safe to Expand to Homebrew Next?

**Conditional yes.** The adapter pattern is proven and thin. Before expanding:

1. Resolve the Trash vs permanent deletion question in PulseCore
2. Consider whether Homebrew cleanup needs special handling (it uses `brew cleanup` command, not directory deletion)
3. The adapter should remain a single delegator per profile type, not a monolithic adapter

The pattern scales: each new profile gets a delegator (or the same delegator with a profile selector), and ComprehensiveOptimizer's scanner methods call the delegator instead of implementing the scan inline.

---

## Build Status

- **Build:** PASS
- **PulseCoreTests:** 26/26 PASS
- **App tests:** 4 pre-existing failures (unrelated to this change)
