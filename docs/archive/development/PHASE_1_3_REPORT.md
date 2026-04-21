# Phase 1.3 Integration Report: Node.js Cache Extraction

**Date:** 2026-04-15
**Branch:** phase0-hardening
**Parent:** Phase 1.2a (e12720b)
**Scope:** Extract Node.js package manager cache cleanup as narrow PulseCore slice

---

## Summary

Node.js package manager cache cleanup (npm, yarn, pnpm) is now delegated to PulseCore `NodeEngine`. All items use `.file` action for file-based deletion — no command execution complexity. A thin `NodeDelegator` in the app layer maps between app and PulseCore types. `ComprehensiveOptimizer` delegates npm/yarn/pnpm scanning to NodeDelegator instead of inline path iteration.

---

## Node Cache Locations Handled

| Package Manager | Cache Path | Executable Check | Min Size |
|----------------|------------|-----------------|----------|
| npm | `~/.npm` | `npm` (via `which`) | 50 MB |
| yarn | `~/Library/Caches/Yarn` | `yarn` (via `which`) | 50 MB |
| pnpm | `~/Library/pnpm/store` | `pnpm` (via `which`) | 50 MB |

**Not handled (out of scope):**
- Project-local `node_modules` directories
- Global package removal (`npm list -g`, `yarn global remove`, etc.)
- Bun, pip, Go, Cargo, Gradle, TypeScript, Vite caches (remain in app's inline scanner)
- Docker, browser, system caches

---

## Design Decisions

### File-based, not command-based
Unlike Homebrew (which requires `brew cleanup` commands), Node caches are simple directories that can be safely deleted. All Node items use `.file` action, routing through `CleanupEngine.executeDelete()` with the configured `FileOperationPolicy` (Trash-first by default).

### Executable check for safety
Each cache is only scanned if its corresponding package manager executable is found in PATH (via `/usr/bin/which`). This prevents false positives from orphaned cache directories when the tool was uninstalled.

### Conservative thresholds
50 MB minimum threshold (higher than the app's 20 MB inline threshold) to avoid noise from small caches. Paths are well-known and hardcoded — no project scanning or glob patterns.

### NodeEngine.apply() is intentionally empty
Since Node items use `.file` action, the actual deletion is handled by `CleanupEngine.apply()` via `FileOperationPolicy`. `NodeEngine.apply()` returns an empty result. `NodeDelegator.apply()` creates a single-item plan and delegates to `CleanupEngine`, following the same pattern as `XcodeDelegator`.

---

## Files Changed

### New (2)

| File | Purpose |
|------|---------|
| `Sources/PulseCore/NodeEngine.swift` | Scans npm/yarn/pnpm caches via DirectoryScanner. Checks executable availability via `which`. Returns `CleanupPlan` with `.file` actions. |
| `Tests/PulseCoreTests/NodeEngineTests.swift` | 15 new tests: NodeEngine scan (7), routing (6), mixed profiles (2). |

### Modified (4)

| File | Change |
|------|--------|
| `Sources/PulseCore/CleanupPlan.swift` | Added `case node` to `CleanupProfile` enum. |
| `Sources/PulseCore/CleanupEngine.swift` | Added Node scanning via `NodeEngine` when `.node` profile is set. |
| `MemoryMonitor/Sources/Services/NodeDelegator.swift` | Thin adapter mapping Node scan/apply between app and PulseCore types. |
| `MemoryMonitor/Sources/Services/ComprehensiveOptimizer.swift` | Added `nodeDelegator` property. `scanDeveloperCaches()` delegates npm/yarn/pnpm to `nodeDelegator.scan()`. `executeCleanupItem()` routes Node items via `nodeDelegator.apply()`. Added `isNodeProfileItem()` helper. Removed npm/yarn/pnpm from inline `devCachePaths` list. |

**Net diff:** +420 / -15 lines

---

## Commands Run

```bash
swift build                           # Build — PASS
swift test --filter PulseCoreTests   # 61 tests, 0 failures — PASS
```

---

## Pass/Fail Results

| Test Suite | Tests | Failures |
|------------|-------|----------|
| `CleanupActionTests` | 2 | 0 |
| `CleanupEngineTests` | 11 | 0 |
| `CleanupRoutingTests` | 5 | 0 |
| `HomebrewScanActionTests` | 2 | 0 |
| `HomebrewEngineTests` | 7 | 0 |
| `MixedProfileTests` | 2 (all new) | 0 |
| `NodeEngineTests` | 7 (all new) | 0 |
| `NodeRoutingTests` | 6 (all new) | 0 |
| `CleanupPlanTests` | 2 | 0 |
| `CleanupPriorityTests_PulseCore` | 2 | 0 |
| `DirectoryScannerTests` | 2 | 0 |
| `SafetyValidatorTests` | 2 | 0 |
| `XcodeDelegatorIntegrationTests` | 11 | 0 |
| **Total** | **61** | **0** |

### New Tests Added (15)

| Test | What It Verifies |
|------|-----------------|
| `testScan_NoPackageManagerInstalled_ReturnsEmptyPlan` | Scan doesn't crash on any env |
| `testScan_ItemsHaveCorrectCategory` | All Node items use `.developer` |
| `testScan_ItemsHaveFileAction` | All Node items use `.file` (not `.command`) |
| `testScan_ItemsHaveCorrectPriority` | All Node items use `.medium` priority |
| `testScan_ItemsUseKnownCachePaths` | All items use known, hardcoded paths |
| `testApply_ReturnsEmptyResult` | NodeEngine.apply() returns empty (delegated) |
| `testIsExecutable_NotFound_ReturnsFalse` | `which` check works for non-existent tools |
| `testScan_NodeProfile_ReturnsNodeItems` | CleanupEngine with `.node` profile returns items |
| `testScan_NoProfiles_ReturnsEmptyPlan` | Empty profiles → empty plan |
| `testApply_NodeItem_DeletesRealDirectory` | File-based deletion works for real dirs |
| `testApply_NodeItem_SkipsProtectedPath` | Protected paths (System/Library) blocked |
| `testApply_NodeItem_RespectsExclusions` | User exclusions respected |
| `testApply_NodeItem_NonexistentPath_ReturnsZeroFreed` | Missing paths → 0 freed |
| `testScan_MultipleProfiles_DoesNotCrash` | Xcode + Homebrew + Node scan together |
| `testApply_MixedPlan_FileAndCommandItems` | Mixed `.file` + `.command` plans work |

---

## PulseCore Cleanliness Verified

| Constraint | Status |
|------------|--------|
| No AppKit | Verified — NodeEngine imports only Foundation |
| No SwiftUI | Verified |
| No ObservableObject | Verified |
| No AppSettings dependency | Verified — NodeEngine has no dependencies on app state |
| Pure data types | Verified — uses CleanupPlan/CleanupResult only |

---

## Unresolved Issues

1. **Threshold mismatch**: PulseCore uses 50 MB minimum, app's inline scanner uses 20 MB. The app will show more items than PulseCore for the same cache. This is acceptable for now — the higher threshold in PulseCore is more conservative. Future: make threshold configurable via `scan(minSizeMB:)`.

2. **Bun cache not yet delegated**: Bun (`~/.bun/install/cache`) remains in the app's inline `devCachePaths` list. It's a Node-adjacent package manager but has different executable detection (`bun` vs `which bun`). Deferred to a future slice.

3. **No per-item size estimation**: `DirectoryScanner.directorySizeMB()` uses `du -sk` which traverses the entire directory. For very large caches (several GB), this can be slow. The app's inline scanner uses `DirectorySizeUtility.quickDirectorySizeMB` with `maxItems` limits for faster estimation. Future: add a size limit option to `DirectoryScanner`.

---

## Whether It Is Safe to Proceed to the Next Slice

**Yes.** The Node slice is working, tested, and follows all established patterns:

1. **File-based path works end-to-end**: 6 dedicated routing tests verify that `.file` actions go through `executeDelete()`, not command execution. Real directory deletion is verified.

2. **Safety is preserved**: Protected path blocking (2 tests), user exclusions (2 tests), and non-existent paths (1 test) all verified.

3. **No regressions**: All 46 pre-existing tests still pass. No changes to Xcode/Homebrew/DeletionStrategy/FileOperationPolicy behavior.

4. **Thin adapter confirmed**: `NodeDelegator` is ~100 lines of pure type mapping.

5. **Executable check adds safety**: `which` check prevents scanning for uninstalled tools — no false positives from orphaned caches.

### Recommended Next Slice Candidates (in order)

1. **Browser caches** (Chrome, Safari, Firefox) — file-based, well-known paths, similar pattern to Node
2. **Docker** (prune images/containers/volumes) — command-based, similar to Homebrew
3. **System caches** — file-based but requires careful safety validation
