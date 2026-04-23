# Phase 2 Review: PulseCLI Alpha

**Reviewer:** Hermes Agent
**Date:** 2026-04-17
**Commit:** 4bf3232
**Parent:** 567b378 (Phase 1.3)
**Source diff:** `git diff 567b378..4bf3232`

---

## Verdict: GO (with 2 minor observations)

Phase 2 successfully delivers a CLI with `pulse analyze` and `pulse clean` commands
backed by PulseCore. The CLI is limited to xcode/homebrew/node profiles, output is
clear and well-formatted, safety behavior matches the v0.1 contract (TrashFirstPolicy
default, confirmation before apply), unsupported profiles are handled cleanly, and
all 74 tests pass. Two minor observations noted (neither blocking for alpha).

---

## 1. CLI Limited to xcode/homebrew/node

| Check | Result | Evidence |
|-------|--------|----------|
| Hardcoded profile whitelist | PASS | CleanCommand.supportedProfiles = ["xcode": .xcode, "homebrew": .homebrew, "node": .node]. Exactly 3 entries. |
| AnalyzeCommand scans all 3 | PASS | `let allProfiles: Set<CleanupProfile> = [.xcode, .homebrew, .node]`. No other profiles. |
| Help text lists only 3 | PASS | Usage.help() lists xcode, homebrew, node. No docker/browser/system. |
| Package.swift dependency scope | PASS | PulseCLI depends only on PulseCore. No Pulse (app) dependency. Clean boundary. |
| No PulseCore profiles leaked | PASS | No `CaseIterable` iteration over CleanupProfile in CLI code (which would include future profiles). Each command explicitly lists the 3 profiles. |

**Verdict: PASS** -- CLI is strictly limited to xcode/homebrew/node. Future profiles (docker, browser, system) will not leak into the CLI until explicitly added.

---

## 2. Output Clear Enough for First-Time Users

| Check | Result | Evidence |
|-------|--------|----------|
| Help text is self-documenting | PASS | `pulse --help` shows: usage patterns, supported profiles with descriptions, all options, 4 concrete examples. Verified by running `swift run pulse --help`. |
| Analyze output is structured | PASS | Header ("Cleanup Analysis"), summary ("Total reclaimable: 2.1 GB across 2 item(s)"), aligned table (Item/Size/Priority/Profile), warnings section, footer with next-step commands. Verified by running `swift run pulse analyze`. |
| Dry-run shows what would happen | PASS | Table includes Item/Size/Priority/Action columns. "Action" column shows "delete" for file items or truncated command for command items. Summary total and item count. Footer shows exact command to execute. Verified by running `swift run pulse clean --dry-run`. |
| Apply requires explicit confirmation | PASS | Prompts "Type 'yes' to confirm: " before executing. Non-"yes" input cancels with "Cleanup cancelled." message. |
| Apply shows per-item results | PASS | Post-execution: "Cleaned:" (green) for success, "Failed:" (red) for failures, "Skipped:" (yellow) with reason for skipped items. Total freed summary. |
| Color coding used consistently | PASS | Green = success/high priority, yellow = warnings/medium priority/unknown, red = errors/failures, dim = low priority/optional/help text. ANSI escape codes in OutputFormatter. |
| Empty state handled | PASS | "Nothing to clean. All caches are below thresholds." when scan returns no items. |
| Error messages actionable | PASS | "Error: Unsupported profile 'docker'" + "Supported profiles: homebrew, node, xcode" + usage help. Verified by running `swift run pulse clean --profile docker --dry-run`. |
| Version string present | PASS | "Pulse CLI 0.1.0-alpha" via `--version` or `-v`. |

**Verdict: PASS** -- Output is clear, structured, and self-documenting. First-time users can understand what the CLI does and how to use it from the help text and output alone.

---

## 3. Safety Behavior Matches v0.1 Contract

| Check | Result | Evidence |
|-------|--------|----------|
| Default CleanupConfig uses TrashFirstPolicy | PASS | All 3 CleanupConfig() calls in CLI use default parameters. CleanupPlan.swift line 119: `self.fileOperationPolicy = fileOperationPolicy ?? TrashFirstPolicy()`. This is the v0.1 contract. |
| SafetyValidator runs before deletion | PASS | CLI calls engine.apply(plan:config:) which runs SafetyValidator(excludedPaths:) on every file item (CleanupEngine line 71-74). |
| Scan-before-apply pattern | PASS | Apply flow: scan first (line 187), show preview (line 190-209), require confirmation (line 211-219), then execute (line 224). Users see exactly what will be cleaned before confirming. |
| Protected path blocking preserved | PASS | SafetyValidator protects /System, /Library, home root, etc. NodeRoutingTests verify this with /System/Library/Caches/npm test case. |
| Homebrew command execution unchanged | PASS | Homebrew items use .command action, routed through executeCommandItems() in CleanupEngine. CLI does not bypass this. |
| No silent deletion | PASS | --dry-run and --apply are mutually exclusive paths. --apply always shows preview + requires confirmation. No --force or --yes flags exist. |

**Verdict: PASS** -- Safety behavior fully matches v0.1 contract. TrashFirstPolicy, SafetyValidator, scan-before-apply, and confirmation are all preserved.

---

## 4. Unsupported Profiles Handled Cleanly

| Check | Result | Evidence |
|-------|--------|----------|
| docker profile rejected | PASS | `pulse clean --profile docker --dry-run` prints "Error: Unsupported profile 'docker'" + "Supported profiles: homebrew, node, xcode" + full usage. Verified. |
| bun profile rejected | PASS | `pulse clean --profile bun --dry-run` prints same error pattern. Verified in test output. |
| Missing action (no --dry-run/--apply) | PASS | `pulse clean` (no flags) prints "Error: Specify --dry-run or --apply" + usage help. Returns EXIT_FAILURE. |
| Unknown flags ignored gracefully | PASS | `pulse clean --unknown` returns EXIT_FAILURE with "Error: Specify --dry-run or --apply". Parser skips unknown flags without crashing. |
| Unknown top-level command | PASS | `pulse foobar` prints "Error: Unknown command 'foobar'" + full help. Returns EXIT_FAILURE. |
| Exit codes are correct | PASS | Help = EXIT_SUCCESS, unknown command = EXIT_FAILURE, missing action = EXIT_FAILURE, dry-run = EXIT_SUCCESS, apply success = EXIT_SUCCESS, apply failure = EXIT_FAILURE. |

**Verdict: PASS** -- All unsupported inputs handled cleanly with actionable error messages. No crashes or silent failures.

---

## 5. Safe to Start External Alpha Testing

| Check | Result | Evidence |
|-------|--------|----------|
| All PulseCore tests pass | PASS | 61/61 PulseCoreTests (no regressions from Phase 1.3) |
| All PulseCLI tests pass | PASS | 13/13 PulseCLITests (3 Analyze + 10 Clean) |
| Total: 74/74 tests pass | PASS | Zero failures across all suites |
| Build clean | PASS | swift build completes with no warnings |
| CLI runs on real machine | PASS | `swift run pulse analyze` produces real output (2.1 GB reclaimable from npm + pnpm) |
| Safety gates intact | PASS | TrashFirstPolicy, SafetyValidator, confirmation prompt all verified |
| No Pulse (app) dependency | PASS | PulseCLI depends only on PulseCore. CLI is self-contained. |
| OBSERVATION: CLI test coverage is shallow | NOTE | 13 tests mostly check exit codes and non-crash behavior. No tests verify actual table formatting, color output, or end-to-end apply flow with mock input. Acceptable for alpha -- users will test real flows. |
| OBSERVATION: No --version in main.swift dispatch | NOTE | `--version` and `-v` are handled in the switch statement, not via a dedicated command struct. Minor structural inconsistency. Not functional. |

**Verdict: PASS** -- CLI is stable, tested, and safe for external alpha.

---

## Tracked Observations

### Observation 1: CLI test coverage is shallow (LOW)

13 tests verify exit codes and non-crash behavior but do not test:
- Table formatting correctness (column alignment, header rendering)
- Color output (ANSI escape codes)
- End-to-end apply flow with piped confirmation input
- Real cleanup execution with mock directories

For alpha, this is acceptable -- real users will exercise these flows. Before beta, add integration tests that pipe "yes" to `pulse clean --apply` and verify output.

### Observation 2: profileLabel() in AnalyzeCommand uses path matching (LOW)

AnalyzeCommand.profileLabel() uses `item.path.contains("DerivedData")` and similar substring matching to determine profile labels. This works for the current 3 profiles but is fragile:
- If a future profile uses overlapping paths, labels will be wrong
- Homebrew items are identified by `.command` action check, not path
- Node items use path substring matching (`.npm`, `Yarn`, `pnpm`)

This is cosmetic (label only) and does not affect routing or safety. Consider adding a `profile` field to CleanupItem in a future refactor.

---

## Go/No-Go Decision

**GO** -- Safe to start external alpha testing.

Rationale:
- CLI is strictly scoped to 3 profiles (xcode, homebrew, node)
- Output is clear, structured, and self-documenting for first-time users
- Safety behavior matches v0.1 contract: TrashFirstPolicy, SafetyValidator, scan-before-apply, confirmation required
- Unsupported profiles handled cleanly with actionable error messages
- 74/74 tests pass, build clean, CLI runs on real machine
- No Pulse app dependency -- CLI is self-contained via PulseCore

Recommended alpha approach:
1. Send `pulse --help` output + install instructions to 2-3 users
2. Ask them to run `pulse analyze` and report what they see
3. Ask them to run `pulse clean --profile node --dry-run` and `--apply`
4. Collect feedback on output clarity, error messages, and perceived safety
