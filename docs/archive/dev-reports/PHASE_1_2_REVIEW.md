# Phase 1.2 Review: Homebrew as PulseCore Slice

**Reviewer:** Hermes Agent
**Date:** 2026-04-15
**Commit:** 90f30c3
**Parent:** 87c9d70 (Phase 1.1)
**Source diff:** `git diff 87c9d70..90f30c3`

---

## Verdict: GO (with 2 tracked issues)

Phase 1.2 is safe to merge and proceed to the next extraction slice. The Homebrew
slice follows the established adapter pattern, PulseCore stays clean, and all 37
tests pass with zero regressions. Two non-blocking bugs were found that should be
fixed before or during the next slice.

---

## 1. App-Integrated Xcode Path: Safe Defaults Preserved

| Check | Result | Evidence |
|-------|--------|----------|
| Xcode thresholds unchanged | PASS | CleanupEngine.scanXcode() untouched: DerivedData >50MB, Archives >100MB, DeviceSupport >100MB, Simulators >500MB |
| XcodeDelegatorIntegrationTests | PASS | 11/11 tests pass after Homebrew changes (no regression) |
| XcodeDelegator unmodified | PASS | No changes to XcodeDelegator.swift in this commit |
| Trash-first policy for Xcode | PASS | CleanupConfig default is TrashFirstPolicy, unchanged |

**Verdict: PASS** -- No regression to Xcode path. All 11 Xcode integration tests pass.

---

## 2. Homebrew Modeled Cleanly

| Check | Result | Evidence |
|-------|--------|----------|
| Pure Foundation, no framework leakage | PASS | HomebrewEngine imports only Foundation. grep for AppKit/SwiftUI/ObservableObject/AppSettings in PulseCore: 0 matches in HomebrewEngine.swift |
| CLI-based (not file deletion) | PASS | Uses Process to run `brew cleanup --prune=all`, `brew cleanup --dry-run`, `du -sk` |
| Injectable brew path | PASS | `init(brewExecutable:)` with default `/opt/homebrew/bin/brew` |
| HOMEBREW_CACHE env var respected | PASS | `brewCacheDownloadsPath` checks ProcessInfo.environment["HOMEBREW_CACHE"] |
| Safe fallback when not installed | PASS | Returns empty CleanupPlan/CleanupResult if brew path doesn't exist |
| Thresholds consistent | PASS | 50MB minimum for both downloads and reclaimable items (matches Xcode thresholds) |
| BUG: "Homebrew downloads" routing | FAIL | Item path is `~/Library/Caches/Homebrew/downloads` (real FS), NOT `homebrew://`. CleanupEngine.isHomebrewItem() only matches `homebrew://` prefix, so this item routes to file deletion (executeDelete), not command execution. See Issue #1 below. |
| BUG: Dead freedMB code | FAIL | Line 87: `freedMB: afterDownloads > 0 ? 0 : 0` -- ternary always evaluates to 0. afterDownloads is computed but discarded. See Issue #2 below. |

**Verdict: PASS with 2 bugs** -- Core modeling is clean. Two bugs found (one routing, one cosmetic).

---

## 3. Adapter Stayed Thin

| Check | Result | Evidence |
|-------|--------|----------|
| HomebrewDelegator line count | PASS | 70 lines (vs XcodeDelegator at 106 lines) |
| No business logic in adapter | PASS | Only scan(), apply(), and type mapping methods |
| No AppSettings dependency | PASS | No import or reference to AppSettings |
| No UI concerns | PASS | No SwiftUI, ObservableObject, @Published, or view types |
| Pattern parity with XcodeDelegator | PASS | Same structure: init(engine:), scan()->map, apply()->delegate, mapCategory/mapPriority |
| Dependency injection | PASS | `init(engine: HomebrewEngine = HomebrewEngine())` -- testable |

**Verdict: PASS** -- HomebrewDelegator is cleaner and thinner than XcodeDelegator.

---

## 4. PulseCore Remained Clean

| Check | Result | Evidence |
|-------|--------|----------|
| No framework imports | PASS | grep for AppKit/SwiftUI/ObservableObject/Published/AppSettings in Sources/PulseCore/: 0 matches in implementation code (only in header comments) |
| CleanupPlan.swift changes | PASS | Only `case homebrew` added to CleanupProfile enum. Comment updated to "v0.1: Xcode. v0.2: Homebrew." |
| CleanupEngine.swift changes | PASS | Homebrew scan/apply cleanly integrated. isHomebrewItem() routing helper added. No structural changes to Xcode or safety paths. |
| homebrew:// sentinel | PASS | Clean separation: `homebrew://` prefix = command execution, all other paths = file deletion via FileOperationPolicy |
| SafetyValidator scope | PASS | Only applies to non-Homebrew (file-based) items. Homebrew items bypass SafetyValidator (appropriate -- brew manages its own safety). |

**Verdict: PASS** -- PulseCore integrity maintained. No coupling introduced.

---

## 5. Build and Test Verification

| Command | Result | Details |
|---------|--------|---------|
| swift build | PASS | Build complete (0.24s) |
| swift test --filter PulseCoreTests | PASS | 37 tests, 0 failures |
| CleanupEngineTests | PASS | 11/11 (no regression) |
| HomebrewEngineTests (new) | PASS | 7/7 (all new) |
| XcodeDelegatorIntegrationTests | PASS | 11/11 (no regression) |
| SafetyValidatorTests | PASS | 2/2 |
| CleanupPlanTests | PASS | 2/2 |
| CleanupPriorityTests | PASS | 2/2 |
| DirectoryScannerTests | PASS | 2/2 |

**Verdict: PASS** -- Full test suite passes. No regressions.

---

## Tracked Issues

### Issue #1: "Homebrew downloads" item routes to file deletion (MEDIUM)

**Location:** HomebrewEngine.swift line 38 + CleanupEngine.swift line 187

**Problem:** The "Homebrew downloads" cleanup item uses path `brewCacheDownloadsPath`
which resolves to `~/Library/Caches/Homebrew/downloads` (a real filesystem path).
The `isHomebrewItem()` routing check uses `item.path.hasPrefix("homebrew://")`, so
this item does NOT match and falls through to `nonHomebrewItems`, where it gets
deleted via executeDelete (FileManager) instead of `brew cleanup`.

Only "Homebrew old versions" (path: `homebrew://cleanup`) correctly routes to
command execution.

**Severity:** MEDIUM -- The downloads directory IS safe to delete directly
(TrashFirstPolicy, cache directory recreation), so no data loss risk. But it
violates the stated execution model (all Homebrew cleanup should use brew CLI)
and creates inconsistency.

**Fix:** Change line 38 in HomebrewEngine.swift from:
  `path: brewCacheDownloadsPath`
to:
  `path: "homebrew://downloads/\(brewCacheDownloadsPath)"`
or similar sentinel-prefixed path.

**Alternative:** Use a dedicated enum/type to identify execution mode rather
than relying on path prefix string matching (cleaner long-term).

---

### Issue #2: Dead freedMB reporting code (LOW)

**Location:** HomebrewEngine.swift line 87

**Problem:** `freedMB: afterDownloads > 0 ? 0 : 0` -- The ternary always
evaluates to 0 regardless of afterDownloads value. The afterDownloads measurement
on line 84 is computed but discarded.

**Severity:** LOW -- Cosmetic. The Homebrew cleanup step reports 0 MB freed,
which is acknowledged in the existing PHASE_1_2_REPORT.md as an "Unresolved
Issue" (brew doesn't report freed space in a machine-readable way).

**Fix options:**
(a) Run `brew cleanup --dry-run` BEFORE cleanup to capture estimated freed space, report that value
(b) Measure cache size before AND after, report the difference
(c) Leave as-is and document that Homebrew freed space is approximate/unknown

---

## Go/No-Go Decision

**GO** -- Proceed to the next extraction slice (recommended: Node.js as the
next file-based slice, or Docker as the next command-based slice).

Rationale:
- Core architecture is sound (adapter pattern, PulseCore purity, sentinel routing)
- Zero test regressions (37/37 pass, including 11 Xcode tests)
- Both tracked issues are non-blocking: Issue #1 is safe in practice (TrashFirstPolicy),
  Issue #2 is cosmetic (acknowledged)
- The next slice will benefit from fixing these issues incrementally

Recommendation: Fix Issue #1 during the next slice implementation (it is a
5-minute fix that improves routing consistency). Issue #2 can be deferred
until freed-space reporting becomes a user-facing requirement.
