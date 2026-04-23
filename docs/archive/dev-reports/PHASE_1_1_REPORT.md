# Phase 1.1 Integration Report: Safety Parity for Xcode Cleanup

**Date:** 2026-04-14
**Branch:** phase0-hardening
**Parent:** Phase 1 (9a9a012)
**Scope:** Resolve deletion semantics mismatch — make PulseCore use Trash-first behavior for Xcode cleanup

---

## Summary

PulseCore now uses Trash-first deletion by default for all cleanup operations. A `FileOperationPolicy` protocol allows injection of alternative deletion strategies (e.g., permanent delete for tests). The Xcode integration path through `XcodeDelegator` automatically uses `TrashFirstPolicy`, matching the app's original safety model.

---

## Files Changed

### Modified (4)

| File | Change |
|------|--------|
| `Sources/PulseCore/CleanupPlan.swift` | Added `DeletionStrategy` enum (`.trash`, `.permanent`), `FileOperationPolicy` protocol, `TrashFirstPolicy` struct, `PermanentDeletePolicy` struct. Extended `CleanupConfig` with `deletionStrategy` and `fileOperationPolicy` fields. |
| `Sources/PulseCore/CleanupEngine.swift` | Changed `executeDelete(_:policy:)` to accept a `FileOperationPolicy` instead of hardcoded `FileManager.removeItem`. `apply(plan:config:)` passes `config.fileOperationPolicy` to `executeDelete`. |
| `Tests/PulseCoreTests/CleanupEngineTests.swift` | Updated apply tests to use `PermanentDeletePolicy()` for deterministic test assertions (permanent delete, no recreation). |
| `Tests/PulseCoreTests/XcodeDelegatorTests.swift` | Updated existing apply tests to use `PermanentDeletePolicy()`. Added 4 new tests: `testTrashFirstPolicy_MovesToTrash`, `testTrashFirstPolicy_RecreatesCacheDirectory`, `testPermanentDeletePolicy_RemovesPermanently`, `testDefaultConfig_UsesTrashStrategy`. |

**Net diff:** +148 / -19 lines

---

## New Abstractions

### `DeletionStrategy` (enum)
```swift
public enum DeletionStrategy {
    case trash      // Move to Trash (recoverable)
    case permanent  // Permanent delete (not recoverable)
}
```

### `FileOperationPolicy` (protocol)
```swift
public protocol FileOperationPolicy {
    var strategy: DeletionStrategy { get }
    func delete(path: String) throws -> Bool
}
```

### `TrashFirstPolicy` (default implementation)
- Uses `FileManager.trashItem(at:)` — files go to Trash, recoverable by user
- After trashing cache directories (Caches, DerivedData, CoreSimulator, Archives, DeviceSupport, node_modules), recreates the empty directory to prevent app crashes
- **This is the default** for `CleanupConfig.fileOperationPolicy`

### `PermanentDeletePolicy` (test/automation implementation)
- Uses `FileManager.removeItem(atPath:)` — permanent, non-recoverable
- No directory recreation
- Used by tests for deterministic assertions

---

## Deletion Model (Current)

| Context | Policy | Behavior |
|---------|--------|----------|
| Default `CleanupConfig()` | `TrashFirstPolicy` | Trash + cache recreation |
| Xcode via `XcodeDelegator` | `TrashFirstPolicy` (default) | Trash + cache recreation |
| Tests (explicit) | `PermanentDeletePolicy` | Permanent delete |
| Future automation | Configurable | Set via `CleanupConfig` |

---

## Commands Run

```bash
swift build                           # Build — PASS
swift test --filter PulseCoreTests   # 30 tests, 0 failures — PASS
```

---

## Pass/Fail Results

| Test Suite | Tests | Failures |
|------------|-------|----------|
| `CleanupEngineTests` | 8 | 0 |
| `SafetyValidatorTests` | 2 | 0 |
| `CleanupPlanTests` | 2 | 0 |
| `CleanupPriorityTests_PulseCore` | 2 | 0 |
| `DirectoryScannerTests` | 2 | 0 |
| `XcodeDelegatorIntegrationTests` | 11 (7 existing + 4 new) | 0 |
| **Total** | **30** | **0** |

### New Tests Added (4)
| Test | What It Verifies |
|------|-----------------|
| `testTrashFirstPolicy_MovesToTrash` | Files are moved to Trash (not permanently deleted) |
| `testTrashFirstPolicy_RecreatesCacheDirectory` | Cache paths (DerivedData) are recreated after trashing |
| `testPermanentDeletePolicy_RemovesPermanently` | Permanent policy removes files with no recreation |
| `testDefaultConfig_UsesTrashStrategy` | Default `CleanupConfig` uses `.trash` strategy and `TrashFirstPolicy` |

---

## Pre-existing Test Failures (Unrelated)

Same 4 pre-existing failures as Phase 1 — none caused by this change:
- `AppUninstallerTests.testPathSafetyAllowsLibraryPaths`
- `DirectorySizeUtilityTests.testDirectorySizeGB`
- `OperationTypeTests.testAllCases`
- `SmartTriggerMonitorTests.testBatteryThreshold_syncsToAppSettings`

---

## Safety Parity Achieved

| Safety Aspect | Before Phase 1.1 | After Phase 1.1 |
|--------------|-----------------|-----------------|
| Deletion method | Permanent (`removeItem`) | Trash (`trashItem`) |
| Recovery path | None | User can restore from Trash |
| Cache directory recreation | No | Yes (Caches, DerivedData, CoreSimulator, Archives, DeviceSupport) |
| Protected path blocking | Yes (`SafetyValidator`) | Yes (unchanged) |
| User exclusion support | Yes | Yes (unchanged) |
| Configurable per-operation | No | Yes (`CleanupConfig.fileOperationPolicy`) |

---

## Whether It Is Safe to Expand to Homebrew Next

**Yes.** The primary blocker (Trash vs permanent deletion) is resolved. PulseCore now:

1. Defaults to Trash-first deletion with cache directory recreation — matching the app's safety model
2. Provides a clean extension point (`FileOperationPolicy`) for profiles that need different behavior (e.g., Homebrew needs `brew cleanup` command, not file deletion)
3. Tests cover both deletion strategies independently

For Homebrew expansion specifically:
- The `CleanupProfile.homebrew` case can be added to `CleanupProfile` enum
- A `HomebrewDelegator` (parallel to `XcodeDelegator`) can handle `brew` commands
- The `FileOperationPolicy` abstraction is ready — Homebrew cleanup won't use file deletion at all, it will use `Process` to run `brew cleanup`, which is a different operation entirely

The adapter pattern is proven, the safety model is aligned, and the extension points exist.
