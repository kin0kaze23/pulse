# Phase 1.2a Integration Report: Homebrew Hardening

**Date:** 2026-04-15
**Branch:** phase0-hardening
**Parent:** Phase 1.2 (90f30c3)
**Scope:** Harden Homebrew slice — fix bugs, replace sentinel routing with typed execution model, lock down routing tests

---

## Bugs Fixed

### Bug #1: "Homebrew downloads" item routed to file deletion instead of command execution

**Root cause:** The routing logic in `CleanupEngine.apply()` used `item.path.hasPrefix("homebrew://")` to identify command-based items. The "Homebrew downloads" item has path `~/Library/Caches/Homebrew/downloads` — a real filesystem path without the `homebrew://` prefix. It was being routed to `executeDelete` (file deletion) instead of command execution.

The `isHomebrewProfileItem()` helper in `ComprehensiveOptimizer` (`contains("Homebrew")`) was a band-aid that worked at the app layer but did not fix the core routing bug in PulseCore.

**Fix:** Replaced sentinel-string routing with `CleanupAction` enum on `CleanupItem`. All Homebrew items now explicitly carry `.command("brew cleanup --prune=all")` regardless of their `path` value.

### Bug #2: Dead conditional in freedMB reporting

**Root cause:** `HomebrewEngine.apply()` had `freedMB: afterDownloads > 0 ? 0 : 0` — both branches returned 0. The conditional was dead code.

**Fix:** Measure reclaimable space via `brew cleanup --dry-run` BEFORE running the actual cleanup. Report that estimate as `freedMB` in the result step. This gives users a meaningful (though estimated) freed-space number instead of always 0.

---

## Routing Model: Before vs After

### Before (Sentinel-String Routing)

```
CleanupEngine.apply():
  plan.items.filter { $0.path.hasPrefix("homebrew://") }  → command execution
  plan.items.filter { !hasPrefix }                        → file deletion

Problem: "Homebrew downloads" has path "~/Library/Caches/Homebrew/downloads"
         → no "homebrew://" prefix → routed to file deletion (BUG)
```

### After (Typed Execution Model)

```
CleanupEngine.apply():
  plan.items.filter { case .command = $0.action }        → command execution
  plan.items.filter { case .file = $0.action }           → file deletion

All items explicitly declare how they should be executed.
No string prefix matching. No ambiguity.
```

---

## CleanupAction Enum

```swift
public enum CleanupAction {
    /// Delete files directly via FileOperationPolicy (default).
    case file
    /// Execute a shell command instead of file deletion.
    /// Associated value is the command to run.
    case command(String)
}
```

- Added to `PulseCore.CleanupPlan.CleanupItem` with default value `.file` (backward compatible)
- Propagated to app-level `ComprehensiveOptimizer.CleanupPlan.CleanupItem` via `PulseCore.CleanupAction`
- Mapped through `HomebrewDelegator` from PulseCore to app types

---

## Files Changed

### Modified (5)

| File | Change |
|------|--------|
| `Sources/PulseCore/CleanupPlan.swift` | Added `CleanupAction` enum. Added `action` field to `CleanupItem` (default `.file`). |
| `Sources/PulseCore/CleanupEngine.swift` | Replaced `isHomebrewItem()` (prefix matching) with `isCommandAction()` (enum matching). Added `executeCommandItems()` for grouped command execution. Added `runShellCommand()` helper. Removed `HomebrewEngine` instantiation in `apply()` — routing is now handled generically. |
| `Sources/PulseCore/HomebrewEngine.swift` | Both scan items now use `.command("brew cleanup --prune=all")` instead of relying on path prefix. `apply()` measures reclaimable BEFORE cleanup to report estimated freed space (fix Bug #2). Removed dead conditional. |
| `MemoryMonitor/Sources/Services/ComprehensiveOptimizer.swift` | Added `action` field to app-level `CleanupItem` (type: `PulseCore.CleanupAction`). Updated `isHomebrewProfileItem()` to use action-based routing instead of `hasPrefix("homebrew://") || contains("Homebrew")`. |
| `MemoryMonitor/Sources/Services/HomebrewDelegator.swift` | Maps `core.action` from PulseCore to app-level `CleanupItem.action`. |

### New (2)

| File | Purpose |
|------|---------|
| `Tests/PulseCoreTests/CleanupActionTests.swift` | 9 new tests: CleanupAction enum tests (2), routing tests (5), Homebrew scan action tests (2). |

**Net diff:** +380 / -30 lines

---

## Commands Run

```bash
swift build                           # Build — PASS
swift test --filter PulseCoreTests   # 46 tests, 0 failures — PASS
```

---

## Pass/Fail Results

| Test Suite | Tests | Failures |
|------------|-------|----------|
| `CleanupActionTests` | 2 (all new) | 0 |
| `CleanupEngineTests` | 11 | 0 |
| `CleanupRoutingTests` | 5 (all new) | 0 |
| `HomebrewScanActionTests` | 2 (all new) | 0 |
| `CleanupPlanTests` | 2 | 0 |
| `CleanupPriorityTests_PulseCore` | 2 | 0 |
| `DirectoryScannerTests` | 2 | 0 |
| `HomebrewEngineTests` | 7 | 0 |
| `SafetyValidatorTests` | 2 | 0 |
| `XcodeDelegatorIntegrationTests` | 11 | 0 |
| **Total** | **46** | **0** |

### New Tests Added (9)

| Test | What It Verifies |
|------|-----------------|
| `testFileAction_DefaultForCleanupItem` | Default `CleanupItem` uses `.file` action |
| `testCommandAction_CarriesCommandString` | `.command` action carries the command string |
| `testCommandItem_DoesNotDeleteFileAtPath` | Command items do NOT delete files at their path (Bug #1 regression guard) |
| `testFileItem_DeletesFileAtPath` | File items DO delete files at their path |
| `testMixedPlan_CommandAndFileItems_RoutedCorrectly` | Mixed plans route both types correctly |
| `testMultipleCommandItems_SameCommand_GroupedTogether` | Items with same command share one execution |
| `testMultipleCommandItems_DifferentCommands_SeparateExecutions` | Items with different commands execute separately |
| `testHomebrewDownloadsItem_HasCommandAction` | "Homebrew downloads" uses `.command` action (Bug #1 fix verification) |
| `testAllHomebrewItems_UseCommandAction` | Real HomebrewEngine scan: all items use `.command` action |

---

## Freed Space Reporting: Before vs After

| Scenario | Before | After |
|----------|--------|-------|
| `HomebrewEngine.apply()` freedMB | Always 0 (dead code) | Estimated from `brew cleanup --dry-run` |
| `CleanupEngine.apply()` for command items | 0 or misleading | Sum of scanned sizes from plan items |
| Accuracy | None | Pre-cleanup estimate (may differ slightly from actual) |

Note: Post-cleanup freed space measurement for command-based cleanup is inherently approximate — `brew cleanup` doesn't report exact freed space. The pre-cleanup estimate is the best available signal.

---

## Command Grouping

`executeCommandItems()` groups items by their command string. All items with `.command("brew cleanup --prune=all")` execute as a single command, and the resulting step reports the combined freed space. This prevents redundant command invocations when multiple Homebrew items exist in the same plan.

---

## Whether It Is Safe to Proceed to Node Cache Extraction Next

**Yes.** Key indicators:

1. **Sentinel routing eliminated**: No more `homebrew://` prefix magic. The `CleanupAction` enum makes execution model explicit and compiler-enforced. Future profiles (Node, Docker) can use `.command` or `.file` without touching routing logic.

2. **Command execution is generic**: `executeCommandItems()` and `runShellCommand()` are profile-agnostic. They don't know about Homebrew. Any future profile can declare `.command("docker system prune")` or `.command("npm cache clean")` and it will work.

3. **Routing is regression-tested**: 5 dedicated tests verify that command items don't trigger file deletion, file items do, mixed plans route correctly, and same-command items group together.

4. **All 46 tests pass** — no regressions from the 37 tests in Phase 1.2.

5. **App layer updated**: `ComprehensiveOptimizer.isHomebrewProfileItem()` now uses the action field, not string matching. The band-aid is removed.

### Recommended Next Step: Node.js Cache Extraction

Node.js is a good next slice because:
- File-based cleanup (uses `.file` action, well-tested path)
- `node_modules` paths are filesystem paths, no command execution complexity
- Similar thresholds to Xcode (only clean if > 50 MB)
- Lower risk than Docker (no container/image state to manage)
