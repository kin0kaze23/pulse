# Phase 1.3 Review: Node.js Cache Extraction

**Reviewer:** Hermes Agent
**Date:** 2026-04-17
**Commit:** 567b378
**Parent:** e12720b (Phase 1.2a)
**Source diff:** `git diff e12720b..567b378`

---

## Verdict: GO (with 1 minor inconsistency)

Phase 1.3 successfully extracts Node.js package manager caches (npm, yarn, pnpm)
as a PulseCore slice. All 61 tests pass with zero regressions. The Node slice
is file-based only (`.file` action), uses well-known global cache paths, and
has executable-gated scanning. One minor inconsistency noted (dead parameter)
is not blocking.

---

## 1. Node Slice Limited to Caches/Stores Only

| Check | Result | Evidence |
|-------|--------|----------|
| Paths are global caches only | PASS | NodeEngine.CacheDefinition.all lists exactly 3 paths: `~/.npm`, `~/Library/Caches/Yarn`, `~/Library/pnpm/store` |
| No project-local node_modules | PASS | grep for `node_modules` in NodeEngine.swift: only a comment saying "no project-local node_modules". No code references. |
| No project scanning or glob patterns | PASS | No recursive directory scanning, no find commands, no path globbing. Only 3 hardcoded global cache paths. |
| No global package removal | PASS | No `npm list -g`, `yarn global remove`, or similar commands. Pure directory deletion. |
| Executable-gated scanning | PASS | Each cache checks `/usr/bin/which <tool>` before scanning. If npm/yarn/pnpm not installed, that cache is skipped. |
| Conservative thresholds | PASS | 50 MB minimum (same as Xcode/Homebrew). Higher than app's inline 20 MB threshold. |
| Bun deferred correctly | PASS | Bun (`~/.bun/install/cache`) remains in app's inline devCachePaths list, not delegated. Correctly out of scope. |
| Node items use .file action | PASS | All 3 cache items use `action: .file`. No command execution complexity. |

**Verdict: PASS** -- Slice is strictly limited to global package manager caches. No risky project paths included.

---

## 2. No Project-Local node_modules or Risky Paths Included

| Check | Result | Evidence |
|-------|--------|----------|
| No node_modules scanning in NodeEngine | PASS | NodeEngine.swift has zero references to node_modules in code (only a comment in line 19). |
| isNodeProfileItem uses exact path match | PASS | Checks `nodePaths.contains(item.path)` against 3 specific paths. No substring matching (unlike isHomebrewProfileItem in 1.2 which had `contains("Homebrew")`). |
| Paths are user-owned cache directories | PASS | `~/.npm`, `~/Library/Caches/Yarn`, `~/Library/pnpm/store` — all user-owned, well-known cache locations. Safe to delete. |
| SafetyValidator still protects | PASS | Node items go through CleanupEngine.apply() -> SafetyValidator for protected path checks. 2 tests verify this. |
| TrashFirstPolicy still applies | PASS | Default FileOperationPolicy is TrashFirstPolicy. Cache directories are recreated after trashing (line 63 in CleanupPlan.swift pre-existing logic). |

**Verdict: PASS** -- No project-local or risky paths. All paths are user-owned global caches with SafetyValidator protection.

---

## 3. Adapter Stayed Thin

| Check | Result | Evidence |
|-------|--------|----------|
| NodeDelegator line count | PASS | 113 lines (XcodeDelegator: 106, HomebrewDelegator: 70) |
| No business logic in adapter | PASS | Only scan(), apply(), and type mapping methods (mapItem, mapCategory, mapPriority) |
| No AppSettings dependency | PASS | No import or reference to AppSettings |
| No UI concerns | PASS | No SwiftUI, ObservableObject, @Published, or view types |
| Dependency injection | PASS | `init(engine:nodeEngine:)` with defaults — testable |
| Pattern parity with other delegators | PASS | Same structure: scan()->map, apply()->delegate, type mapping. Consistent with XcodeDelegator. |
| MINOR: excludedPaths is dead parameter in scan() | NOTE | NodeDelegator.scan(excludedPaths:) accepts but does not use the parameter. XcodeDelegator passes it to CleanupConfig (also unused at scan time). Consistent with Xcode pattern but both could be cleaned up. Filtering happens at apply time via SafetyValidator. |

**Verdict: PASS** -- Adapter is thin, consistent with established pattern. One dead parameter shared with XcodeDelegator.

---

## 4. PulseCore Remained Clean

| Check | Result | Evidence |
|-------|--------|----------|
| No framework imports | PASS | NodeEngine imports only Foundation. grep for AppKit/SwiftUI/ObservableObject/Published/AppSettings in NodeEngine.swift: 0 matches in implementation code (only in header comment) |
| CleanupPlan.swift changes | PASS | Only `case node` added to CleanupProfile enum. Comment updated. |
| CleanupEngine.swift changes | PASS | 6 lines added: `if config.profiles.contains(.node) { NodeEngine().scan() }`. No structural changes to apply() path. |
| NodeEngine.apply() intentionally empty | PASS | Returns empty CleanupResult. File-based deletion is handled by CleanupEngine.apply() via .file action. This is the correct design for file-based profiles. |
| No coupling to app layer | PASS | NodeEngine has zero imports of app types. Uses only PulseCore types (CleanupPlan, CleanupResult, DirectoryScanner). |
| CacheDefinition is private | PASS | NodeEngine.CacheDefinition is private struct. Not exposed publicly. |

**Verdict: PASS** -- PulseCore integrity maintained. No coupling introduced.

---

## 5. Build and Test Verification

| Command | Result | Details |
|---------|--------|---------|
| swift build | PASS | Build complete (0.25s) |
| swift test --filter PulseCoreTests | PASS | 61 tests, 0 failures |
| CleanupActionTests | PASS | 2/2 (no regression) |
| CleanupEngineTests | PASS | 11/11 (no regression) |
| CleanupRoutingTests | PASS | 5/5 (no regression) |
| HomebrewEngineTests | PASS | 7/7 (no regression) |
| HomebrewScanActionTests | PASS | 2/2 (no regression) |
| MixedProfileTests (new) | PASS | 2/2 (all new) |
| NodeEngineTests (new) | PASS | 7/7 (all new) |
| NodeRoutingTests (new) | PASS | 6/6 (all new) |
| CleanupPlanTests | PASS | 2/2 (no regression) |
| CleanupPriorityTests | PASS | 2/2 (no regression) |
| DirectoryScannerTests | PASS | 2/2 (no regression) |
| SafetyValidatorTests | PASS | 2/2 (no regression) |
| XcodeDelegatorIntegrationTests | PASS | 11/11 (no regression) |

**Key new tests:**
- testScan_ItemsUseKnownCachePaths: Verifies all items use exactly the 3 known paths. No surprises.
- testScan_ItemsHaveFileAction: Confirms all Node items use .file, not .command.
- testApply_NodeItem_DeletesRealDirectory: Creates a fake npm cache, deletes it via CleanupEngine, verifies deletion.
- testApply_NodeItem_SkipsProtectedPath: /System/Library/Caches/npm blocked by SafetyValidator.
- testApply_NodeItem_RespectsExclusions: User-excluded paths are skipped.
- testApply_NodeItem_NonexistentPath_ReturnsZeroFreed: Missing paths handled gracefully.
- testScan_MultipleProfiles_DoesNotCrash: Xcode + Homebrew + Node together.
- testApply_MixedPlan_FileAndCommandItems: Mixed .file + .command plan works.

**Verdict: PASS** -- 15 new tests (7 NodeEngine + 6 NodeRouting + 2 MixedProfile), all passing. Zero regressions across 46 pre-existing tests.

---

## Tracked Issues

### Issue: excludedPaths dead parameter in NodeDelegator.scan() (LOW)

**Location:** NodeDelegator.swift line 29

**Problem:** `func scan(excludedPaths: [String])` accepts but does not use the parameter. The XcodeDelegator has the same pattern (passes excludedPaths to CleanupConfig, which is also unused at scan time). Exclusion filtering happens at apply time via SafetyValidator.

**Severity:** LOW -- No functional impact. The excludedPaths parameter is misleading because it suggests scan-time filtering that does not occur. Both XcodeDelegator and NodeDelegator have this issue.

**Fix:** Either (a) remove the parameter from scan() signatures (breaking change), (b) add a doc comment noting it applies at apply-time, or (c) implement actual scan-time filtering in the engines. Deferred.

---

## Go/No-Go Decision

**GO** -- Proceed to the next extraction slice.

Rationale:
- Node slice is strictly scoped to global caches (npm/yarn/pnpm), no project-local paths
- File-based path (.file action) works end-to-end with SafetyValidator protection
- 61/61 tests pass, 15 new tests covering scan properties, routing, safety, and mixed profiles
- No regressions across all 46 pre-existing tests
- PulseCore stays clean, adapter stays thin
- Executable-gated scanning prevents false positives from orphaned caches

Recommended next slice candidates:
1. Browser caches (Chrome, Safari, Firefox) -- file-based, well-known paths, follows Node pattern
2. Docker (prune images/containers/volumes) -- command-based, follows Homebrew pattern
3. System caches -- file-based but requires careful safety validation
