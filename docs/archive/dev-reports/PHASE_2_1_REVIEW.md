# Phase 2.1 Review: Launch Hardening

**Reviewer:** Hermes Agent
**Date:** 2026-04-17
**Commit:** 009bf80
**Parent:** 4bf3232 (Phase 2)
**Source diff:** `git diff 4bf3232..009bf80`

---

## Verdict: GO

Phase 2.1 successfully hardens Pulse CLI for controlled external alpha. The fragile
profileLabel() issue is properly resolved with a compiler-enforced profile field.
The release surface is honest and tightly scoped. First-time install/use is clear.
All 74 tests pass. Ready for controlled external alpha.

---

## 1. First-Time Install/Use Clear Enough

| Check | Result | Evidence |
|-------|--------|----------|
| README has dedicated CLI alpha section | PASS | New section with: build command, 4 usage examples, supported profiles table, "What Pulse Will NOT Touch" section, sample output, 5 known limitations, feedback instructions |
| Build command is one line | PASS | `swift build` -- no dependency installation, no config files, no key setup |
| Sample output matches reality | PASS | README shows "npm cache 1.3 GB Medium node / pnpm store 773 MB Medium node". Live output: identical format, same items, same profile labels |
| Help text is self-contained | PASS | `pulse --help` shows version, usage patterns, all 3 profiles with descriptions, all options, 4 examples. Verified live |
| Alpha feedback template exists | PASS | .github/ISSUE_TEMPLATE/alpha_feedback.md with structured sections: Setup (macOS version, Mac model, build method, branch), What I Did, Results table, Confusion Points, Suggestions, Other Notes |
| Release notes exist | PASS | RELEASE_NOTES_v0.1.0-alpha.md: what's new, commands table, supported profiles, safety features, what's NOT included, install instructions, known issues, feedback link |
| Install path in release notes | PASS | 5-line clone/build/verify sequence with explicit branch: `git checkout phase0-hardening` |
| "What Pulse Will NOT Touch" section | PASS | README explicitly lists 5 categories of things the CLI will never touch: project-local files, system-critical paths, user data, app bundles, other profiles |

**Verdict: PASS** -- A first-time user cloning the repo can build and use the CLI in under 2 minutes with zero configuration. The README, help text, release notes, and feedback template form a complete onboarding surface.

---

## 2. Release Surface Honest and Scoped Correctly

| Check | Result | Evidence |
|-------|--------|----------|
| CLI supports only 3 profiles | PASS | CleanCommand.supportedProfiles = ["xcode", "homebrew", "node"]. No other profiles exposed |
| case system not leaked to CLI | PASS | `case system` added to CleanupProfile enum, but grep for "system" in all CLI source files: 0 matches. The CLI never iterates CaseIterable |
| README honestly labels alpha features | PASS | CLI section labeled "(Alpha)". Profile table marks node as "(CLI alpha)". Docker/browser/system labeled "(app only)" |
| Known limitations documented | PASS | 5 honest limitations in README: only 3 profiles, no scripting mode, Homebrew threshold caveat, stdout only, hardcoded version |
| Known issues in release notes | PASS | 4 known issues documented: hardcoded version, no --yes flag, Homebrew threshold, no JSON output |
| What's NOT included listed | PASS | Release notes explicitly lists: Docker/browser/system cleanup, Bun/pip/Go/Cargo, scheduling/automation, telemetry, config files, concurrent cleanup |
| Version labeled alpha | PASS | "Pulse CLI 0.1.0-alpha" everywhere: --version output, release notes title, feedback template title |
| No overpromising in README | PASS | Features section honestly distinguishes CLI capabilities from app capabilities. No claim of Docker/browser support in CLI |

**Verdict: PASS** -- Release surface is honest, tightly scoped, and clearly labeled as alpha. No overpromising.

---

## 3. Fragile Output Issue Resolved

| Check | Result | Evidence |
|-------|--------|----------|
| profileLabel() replaced with direct field access | PASS | AnalyzeCommand.profileLabel() changed from 12 lines of path substring matching to `return item.profile.rawValue`. Fragile matching eliminated |
| profile field added to CleanupItem | PASS | `public let profile: CleanupProfile` added to CleanupPlan.CleanupItem (line 210) |
| profile is required (no default) | PASS | Init parameter `profile: CleanupProfile` has no default value. Compiler forces all callers to provide it |
| All engines set profile at creation | PASS | Xcode scanXcode(): `.profile: .xcode` on all 4 items. HomebrewEngine: `.profile: .homebrew` on both items. NodeEngine: `.profile: .node` on all items |
| All delegators pass profile through | PASS | XcodeDelegator.mapItem: `profile: core.profile`. HomebrewDelegator.mapItem: `profile: core.profile`. NodeDelegator.mapItem: `profile: core.action` (both directions) |
| All tests updated | PASS | 18 test files updated with `profile:` parameter across CleanupActionTests, CleanupEngineTests, NodeEngineTests, NodeRoutingTests, XcodeDelegatorTests, MixedProfileTests, HomebrewScanActionTests. All use correct profile for their context |
| App-level CleanupItem also has profile | PASS | ComprehensiveOptimizer.CleanupItem now has `let profile: PulseCore.CleanupProfile` field. All 15+ inline items (browsers, Docker, system caches, Trash, etc.) use `.system` |
| CLI reads profile directly | PASS | `item.profile.rawValue` in AnalyzeCommand. No string matching, no heuristics |

**Verdict: PASS** -- The fragile path-based profileLabel() is completely replaced with a compiler-enforced profile field. This is a structural fix, not a band-aid. Future profiles (docker, browser) will automatically work correctly when added.

---

## 4. Ready for Controlled External Alpha

| Check | Result | Evidence |
|-------|--------|----------|
| All PulseCore + PulseCLI tests pass | PASS | 74/74 tests, 0 failures. Verified: swift test --filter "PulseCoreTests\|PulseCLITests" |
| Build clean | PASS | swift build completes with no warnings |
| CLI runs on real machine | PASS | `swift run pulse analyze` produces real output with correct profile labels |
| Safety gates intact | PASS | TrashFirstPolicy default, SafetyValidator, scan-before-apply, confirmation required -- all verified in prior reviews, unchanged |
| No Pulse app dependency for CLI | PASS | PulseCLI depends only on PulseCore. Independent build |
| AppUninstaller test failure is pre-existing | PASS | testPathSafetyAllowsLibraryPaths fails in both Phase 2 and Phase 2.1. Not caused by this change. Outside PulseCore/PulseCLI scope |
| Feedback collection mechanism ready | PASS | GitHub issue template + release notes with feedback instructions |

**Verdict: PASS** -- All gates pass. Ready for controlled external alpha.

---

## Tracked Observations

### Observation 1: AppUninstaller test failure (pre-existing, OUT OF SCOPE)

testPathSafetyAllowsLibraryPaths has 4 assertion failures in both Phase 2 and 2.1.
This is a pre-existing issue in the app test suite, not caused by Phase 2.1 changes.
It is outside PulseCore/PulseCLI scope and does not affect CLI alpha readiness.
Should be fixed in a separate PR.

### Observation 2: profile field has no default value (by design, POSITIVE)

CleanupItem.init requires `profile: CleanupProfile` with no default. This means
all callers must explicitly provide it. This is intentional and correct -- it
prevents the exact kind of bug that profileLabel() was working around. The app-level
CleanupItem items (browsers, Docker, system caches) all use `.system`, which is
now available as a profile case.

---

## Go/No-Go Decision

**GO** -- Proceed to controlled external alpha.

Rationale:
- profileLabel() fragility is permanently fixed with a compiler-enforced profile field
- First-time install/use is clear: one-line build, self-documenting help, structured README
- Release surface is honest: alpha label everywhere, known limitations documented, scope tightly bounded to 3 profiles
- Safety behavior unchanged: TrashFirstPolicy, SafetyValidator, confirmation required
- 74/74 tests pass, build clean, CLI verified on real machine
- Feedback collection mechanism (issue template + release notes) is ready

Recommended alpha approach:
1. Share repo + build instructions with 10-15 macOS developers
2. Point them to README CLI section and RELEASE_NOTES_v0.1.0-alpha.md
3. Ask them to run: `pulse analyze`, `pulse clean --dry-run`, optionally `pulse clean --profile <name> --apply`
4. Collect feedback via .github/ISSUE_TEMPLATE/alpha_feedback.md
5. 1-week feedback window, then triage and plan next iteration
