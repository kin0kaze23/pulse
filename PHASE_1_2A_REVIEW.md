# Phase 1.2a Review: Homebrew Hardening

**Reviewer:** Hermes Agent
**Date:** 2026-04-15
**Commit:** e12720b
**Parent:** 90f30c3 (Phase 1.2)
**Source diff:** `git diff 90f30c3..e12720b`

---

## Verdict: GO (with 1 design observation)

Phase 1.2a successfully fixes both bugs from Phase 1.2 review. The CleanupAction
enum replaces sentinel-string routing with typed, compiler-enforced execution model.
All 46 tests pass with zero regressions. One design observation noted (scan vs apply
asymmetry) is not blocking.

---

## 1. Homebrew Routing: Now Correct and Explicit

| Check | Result | Evidence |
|-------|--------|----------|
| Bug #1 fix: Homebrew downloads routing | PASS | Both scan items in HomebrewEngine now use `.command("brew cleanup --prune=all")` action. No longer relies on path prefix. |
| Bug #2 fix: freedMB dead code | PASS | HomebrewEngine.apply() now measures `measureReclaimableMB()` BEFORE cleanup and reports it as freedMB. Dead conditional removed. |
| CleanupAction enum introduced | PASS | `public enum CleanupAction { case file, case command(String) }` in CleanupPlan.swift |
| Default is .file (backward compatible) | PASS | CleanupItem init has `action: CleanupAction = .file`. Existing Xcode items unaffected. |
| homebrew:// sentinel removed from routing | PASS | grep for `homebrew://` in routing code: 0 matches. Only remains as a descriptive path in HomebrewEngine line 55 and in a comment. |
| isCommandAction() replaces isHomebrewItem() | PASS | CleanupEngine line 185: `if case .command = item.action { return true }` — typed pattern match, no string prefix. |
| App-level isHomebrewProfileItem updated | PASS | ComprehensiveOptimizer now uses `if case .command = item.action { return true }` instead of `hasPrefix("homebrew://") || contains("Homebrew")`. Band-aid removed. |
| HomebrewDelegator maps action | PASS | `action: core.action` passed through from PulseCore to app-level CleanupItem. |
| Regression test: command items don't delete files | PASS | testCommandItem_DoesNotDeleteFileAtPath creates a real file, marks it as .command, applies plan, verifies file still exists. |
| Regression test: file items do delete | PASS | testFileItem_DeletesFileAtPath verifies .file action triggers actual deletion. |

**Verdict: PASS** -- Both bugs fixed. Routing is now typed and compiler-enforced.

---

## 2. Execution Model: Clean Enough for Future Slices

| Check | Result | Evidence |
|-------|--------|----------|
| apply() path is profile-agnostic | PASS | executeCommandItems() groups by command string, runs via runShellCommand(). No knowledge of Homebrew. Works for any `.command(String)` item. |
| Command grouping works | PASS | Items with same command share one execution (testMultipleCommandItems_SameCommand_GroupedTogether). Items with different commands execute separately (testMultipleCommandItems_DifferentCommands_SeparateExecutions). |
| runShellCommand uses /bin/bash -c | PASS | Line 230-243. Generic shell execution, not brew-specific. |
| HomebrewEngine removed from apply() | PASS | CleanupEngine.apply() no longer instantiates HomebrewEngine. HomebrewEngine is only used in scan() (line 32). |
| SafetyValidator still protects file items only | PASS | Command items bypass SafetyValidator (lines 50-59 vs 62-87). Appropriate — SafetyValidator checks filesystem paths, not commands. |
| Freed space reporting improved | PASS | executeCommandItems reports sum of scanned sizes from plan items. HomebrewEngine.apply() reports pre-cleanup estimate. Both provide meaningful numbers. |
| OBSERVATION: scan() is still Homebrew-specific | NOTE | CleanupEngine.scan() still has `if config.profiles.contains(.homebrew) { HomebrewEngine().scan() }`. The scan side is not yet generic like apply(). Adding a new profile requires modifying scan(). |
| OBSERVATION: Dual execution paths for Homebrew | NOTE | App path: HomebrewDelegator.apply() -> HomebrewEngine.apply(). Core path: CleanupEngine.apply() -> executeCommandItems() -> runShellCommand(). Both valid, but worth consolidating when Docker slice is added. |

**Verdict: PASS with 2 observations** -- The apply() path is clean and generic. The scan() side still needs generalization (acceptable for now — Xcode has the same pattern).

---

## 3. Adapter Stayed Thin

| Check | Result | Evidence |
|-------|--------|----------|
| HomebrewDelegator unchanged in structure | PASS | Still 70 lines. Only change: added `action: core.action` to mapItem. |
| No new business logic in adapter | PASS | Pure type mapping: scan()->map, apply()->delegate, mapCategory/mapPriority. |
| ComprehensiveOptimizer impact minimal | PASS | 7 lines changed: added `action` field to CleanupItem, updated isHomebrewProfileItem from string matching to enum pattern match. |
| No new dependencies | PASS | HomebrewDelegator still only imports Foundation and PulseCore. |

**Verdict: PASS** -- Adapter remains thin and clean.

---

## 4. Test Coverage

| Test Suite | Tests | Failures | Notes |
|------------|-------|----------|-------|
| CleanupActionTests (new) | 2 | 0 | Enum defaults, command string carriage |
| CleanupRoutingTests (new) | 5 | 0 | Command-vs-file routing, mixed plans, command grouping |
| HomebrewScanActionTests (new) | 2 | 0 | Bug #1 fix verification, real scan action check |
| CleanupEngineTests | 11 | 0 | No regression |
| HomebrewEngineTests | 7 | 0 | No regression |
| XcodeDelegatorIntegrationTests | 11 | 0 | No regression |
| SafetyValidatorTests | 2 | 0 | No regression |
| CleanupPlanTests | 2 | 0 | No regression |
| CleanupPriorityTests | 2 | 0 | No regression |
| DirectoryScannerTests | 2 | 0 | No regression |
| **Total** | **46** | **0** | **Up from 37 in Phase 1.2** |

**Key new tests:**
- testCommandItem_DoesNotDeleteFileAtPath: Bug #1 regression guard — creates a real file, marks it as .command, applies, verifies file still exists.
- testMixedPlan_CommandAndFileItems_RoutedCorrectly: Both paths work in same plan.
- testMultipleCommandItems_SameCommand_GroupedTogether: Command grouping verified.
- testHomebrewDownloadsItem_HasCommandAction: Direct Bug #1 fix verification.
- testAllHomebrewItems_UseCommandAction: Real scan from HomebrewEngine — all items use .command.

**Verdict: PASS** — 9 new tests, all passing. Strong regression coverage for both bugs.

---

## 5. Build and Gate Verification

| Command | Result | Details |
|---------|--------|---------|
| swift build | PASS | Build complete (0.19s) |
| swift test --filter PulseCoreTests | PASS | 46 tests, 0 failures |

**Verdict: PASS**

---

## Design Observations (Non-Blocking)

### Observation 1: scan() is still profile-specific

CleanupEngine.scan() still has per-profile branches:
```
if config.profiles.contains(.xcode) { scanXcode() }
if config.profiles.contains(.homebrew) { HomebrewEngine().scan() }
```

The apply() path was generalized via CleanupAction enum. The scan() path follows
the same pattern as before. This is acceptable — Xcode has the same structure.
When adding Node.js (file-based) or Docker (command-based), the scan() pattern
will need a similar engine per profile. This is the intended design: each profile
has its own engine for scanning, and CleanupEngine.apply() routes generically.

### Observation 2: Dual execution paths for Homebrew

App-level: ComprehensiveOptimizer.executeCleanupItem -> HomebrewDelegator.apply() -> HomebrewEngine.apply()
Core-level: CleanupEngine.apply() -> executeCommandItems() -> runShellCommand()

Both execute `brew cleanup --prune=all`. The app path goes through HomebrewEngine
(which measures reclaimable before/after), while the core path just runs the command.
This is not a bug — the app path provides better freed-space reporting. But when
Docker is added, it would be cleaner if all command-based items went through the
generic executeCommandItems path. The HomebrewDelegator could be simplified to
just map types and let CleanupEngine.apply() handle execution.

---

## Go/No-Go Decision

**GO** — Proceed to Node.js cache extraction.

Rationale:
- Both Phase 1.2 bugs are fixed with regression tests
- CleanupAction enum makes execution model explicit and compiler-enforced
- apply() path is fully generic — Node.js will use .file, Docker will use .command
- 46/46 tests pass, no regressions
- Adapter stays thin, PulseCore stays clean
- Observations are structural notes, not blockers

Recommended next step: Node.js cache extraction (file-based, uses .file action,
well-tested path, low risk). The scan() side will follow the Xcode pattern
(scanNode() method in CleanupEngine), and the apply() side will automatically
work through the existing file-based routing.
