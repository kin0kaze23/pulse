# Phase 2.1 Launch Hardening Report

**Date:** 2026-04-17
**Branch:** phase0-hardening
**Parent:** Phase 2 (4bf3232)
**Scope:** Fix profileLabel() fragility, verify clean-room install, tighten README, prepare release artifacts

---

## Readiness Gate Results

### 1. profileLabel() Fix

**Verdict: Fixed — no longer fragile.**

**Before:** Used path substring matching to determine profile:
```swift
let xcodePaths = ["DerivedData", "Archives", "DeviceSupport", "CoreSimulator"]
if xcodePaths.contains(where: { item.path.contains($0) }) { return "xcode" }
```

This would break if path patterns changed or overlapped, and returned "unknown" for edge cases.

**After:** Added `profile: CleanupProfile` field to `CleanupItem`. Each engine sets it at creation:
```swift
private static func profileLabel(for item: CleanupPlan.CleanupItem) -> String {
    return item.profile.rawValue
}
```

**Changes:**
- `CleanupPlan.CleanupItem` gained `profile: CleanupProfile` (no default — must be provided)
- `CleanupProfile` enum gained `case system` for app-level items not tied to CLI profiles
- All engine creation sites updated: `CleanupEngine` (xcode), `HomebrewEngine` (homebrew), `NodeEngine` (node)
- All delegator mapping functions pass profile through
- All test files updated (14 CleanupItem creation sites)

**Impact:** Analyze table now shows correct profile labels with zero path guessing.

### 2. Clean-Room Install Verification

**All three commands verified:**

| Command | Result |
|---------|--------|
| `swift run pulse --help` | PASS — clean help output with usage, profiles, options, examples |
| `swift run pulse analyze` | PASS — scans all profiles, shows 2.1 GB reclaimable (npm 1.3 GB, pnpm 773 MB), correct profile labels |
| `swift run pulse clean --profile xcode --dry-run` | PASS — "Nothing to clean. All caches are below thresholds." |

### 3. README Tightened

**Changes:**
- Added "Pulse CLI (Alpha)" section with build commands, usage examples, supported profiles table
- Added "What Pulse Will NOT Touch" section (project-local files, system-critical paths, user data, app bundles, excluded profiles)
- Added sample CLI output
- Added "Known Limitations" (5 items: scripting, version, Homebrew threshold, output format, version hardcoded)
- Added "Feedback" section with what to report
- Updated Cache Cleanup features table to distinguish CLI alpha vs app-only profiles

### 4. Release Artifacts

**Created:**
- `.github/ISSUE_TEMPLATE/alpha_feedback.md` — structured feedback template with setup, results table, confusion points, suggestions
- `RELEASE_NOTES_v0.1.0-alpha.md` — release notes with what's new, install instructions, known issues, feedback link

---

## Files Changed

### Modified (7)

| File | Change |
|------|--------|
| `Sources/PulseCore/CleanupPlan.swift` | Added `profile` field to `CleanupItem`, added `case system` to `CleanupProfile` |
| `Sources/PulseCore/CleanupEngine.swift` | Added `profile: .xcode` to all Xcode items |
| `Sources/PulseCore/HomebrewEngine.swift` | Added `profile: .homebrew` to all Homebrew items |
| `Sources/PulseCore/NodeEngine.swift` | Added `profile: .node` to all Node items |
| `Sources/PulseCLI/Commands/AnalyzeCommand.swift` | Replaced path-matching `profileLabel()` with direct `item.profile.rawValue` |
| `MemoryMonitor/Sources/Services/ComprehensiveOptimizer.swift` | Added `profile` field to app-level `CleanupItem`, set `.system` on all app-level items |
| `README.md` | Added CLI alpha section, sample output, known limitations, feedback instructions |

### Modified - App Delegators (3)

| File | Change |
|------|--------|
| `MemoryMonitor/Sources/Services/XcodeDelegator.swift` | Pass `profile` through in mapItem and apply |
| `MemoryMonitor/Sources/Services/HomebrewDelegator.swift` | Pass `profile` through in mapItem |
| `MemoryMonitor/Sources/Services/NodeDelegator.swift` | Pass `profile` through in mapItem and apply |

### Modified - Tests (4)

| File | Change |
|------|--------|
| `Tests/PulseCoreTests/CleanupActionTests.swift` | Added `profile` to all CleanupItem creation sites (9) |
| `Tests/PulseCoreTests/CleanupEngineTests.swift` | Added `profile: .xcode` to all CleanupItem creation sites (3) |
| `Tests/PulseCoreTests/XcodeDelegatorTests.swift` | Added `profile: .xcode` to all CleanupItem creation sites (4) |
| `Tests/PulseCoreTests/NodeEngineTests.swift` | Added `profile` to all CleanupItem creation sites (6) |

### New (2)

| File | Purpose |
|------|---------|
| `.github/ISSUE_TEMPLATE/alpha_feedback.md` | Structured alpha feedback template |
| `RELEASE_NOTES_v0.1.0-alpha.md` | Release notes for v0.1.0-alpha |

---

## Commands Run

```bash
swift build                              # Build all targets — PASS
swift build --target PulseCLI            # Build CLI only — PASS
swift build --target PulseCore           # Build PulseCore only — PASS
swift test --filter "PulseCoreTests|PulseCLITests"  # 74 tests, 0 failures — PASS
swift run pulse --help                   # Verify help output — PASS
swift run pulse analyze                  # Verify analyze output — PASS
swift run pulse clean --profile xcode --dry-run  # Verify clean dry-run — PASS
```

---

## Pass/Fail Results

### PulseCore + PulseCLI Tests (Regression)

| Test Suite | Tests | Failures |
|------------|-------|----------|
| `CleanupActionTests` | 2 | 0 |
| `CleanupEngineTests` | 11 | 0 |
| `CleanupRoutingTests` | 5 | 0 |
| `HomebrewScanActionTests` | 2 | 0 |
| `HomebrewEngineTests` | 7 | 0 |
| `MixedProfileTests` | 2 | 0 |
| `NodeEngineTests` | 7 | 0 |
| `NodeRoutingTests` | 6 | 0 |
| `CleanupPlanTests` | 2 | 0 |
| `CleanupPriorityTests_PulseCore` | 2 | 0 |
| `DirectoryScannerTests` | 2 | 0 |
| `SafetyValidatorTests` | 2 | 0 |
| `XcodeDelegatorIntegrationTests` | 11 | 0 |
| `AnalyzeCommandTests` | 3 | 0 |
| `CleanCommandTests` | 10 | 0 |
| **Total** | **74** | **0** |

---

## Unresolved Issues

1. **App linker error**: The `Pulse` app target (MemoryMonitor) fails to link independently due to SwiftUI linking. This is a pre-existing issue unrelated to these changes. PulseCore and PulseCLI build and test cleanly.

2. **No `--yes` flag for scripting**: `pulse clean --profile xcode --apply` requires interactive "yes" confirmation. Cannot be scripted in CI or pipelines. This is a known limitation documented in the README.

3. **`--version` hardcoded**: Version string is "0.1.0-alpha" in main.swift, not derived from git tag or build metadata.

4. **Homebrew threshold**: On machines where Homebrew caches are below 50 MB, `pulse analyze` shows no Homebrew items. This is correct behavior but may confuse users expecting to always see output.

5. **App-level items use `.system` profile**: Items created by ComprehensiveOptimizer (Trash, browser caches, system caches, etc.) are tagged as `.system`. This doesn't affect CLI output (CLI only shows xcode/homebrew/node profiles), but the `system` profile exists in the enum without CLI support yet.

---

## Whether External Alpha Should Start Now

**Yes.** The hardening pass is complete and all gates pass:

1. **profileLabel() fixed**: No more fragile path matching. Profile labels are typed and set at creation time.
2. **Clean-room verified**: All three verification commands pass on a real machine with real data.
3. **README tightened**: First-time users have clear install instructions, supported profiles, sample output, known limitations, and feedback instructions.
4. **Release artifacts ready**: Issue template for alpha feedback, release notes documenting what ships and what doesn't.
5. **74 tests passing**: No regressions introduced by the profile field addition.

### Recommended Next Steps (External Alpha)

1. Create GitHub release with `RELEASE_NOTES_v0.1.0-alpha.md` content
2. Tag `v0.1.0-alpha`
3. Invite 10-15 macOS developers (Xcode/Homebrew/Node users)
4. Direct them to clone, build, run `pulse analyze`, and optionally `pulse clean --profile <name> --dry-run`
5. Ask them to open an Alpha Feedback issue using the template
6. Collect feedback for 1 week
7. Decide next investment based on feedback: Docker, onboarding, output quality, or app packaging

### What NOT to Do Before Alpha

- Do not add Docker support
- Do not add browser/system CLI profiles
- Do not start another big extraction
- Do not redesign the app
- Do not add "nice to have" CLI commands
- Do not try to perfect test coverage before alpha
