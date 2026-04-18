# External Alpha Launch Report

**Date:** 2026-04-17
**Tag:** v0.1.0-alpha (361aa87)
**Branch:** phase0-hardening
**Scope:** Ship controlled external alpha for Pulse CLI (xcode, homebrew, node only)

---

## Verification Results

### Clean Clone Flow

All commands verified from a fresh clone:

| Command | Result |
|---------|--------|
| `git clone` from local repo | PASS |
| `git checkout v0.1.0-alpha` | PASS — HEAD at 361aa87 |
| `swift build --product pulse` | PASS — clean build |
| `pulse --help` | PASS — shows all 3 profiles, usage, examples |
| `pulse analyze` | PASS — 2.1 GB reclaimable (npm 1.3 GB, pnpm 773 MB), correct profile labels |
| `pulse clean --profile xcode --dry-run` | PASS — "Nothing to clean. All caches are below thresholds." |
| `swift test --filter "PulseCoreTests\|PulseCLITests"` | PASS — 74 tests, 0 failures |

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

## Files Changed in This Phase

### Modified (3)

| File | Change |
|------|--------|
| `README.md` | Fixed GitHub URLs to kin0kaze23 |
| `.github/ISSUE_TEMPLATE/alpha_feedback.md` | Fixed GitHub URLs to kin0kaze23, reference tag not branch |
| `RELEASE_NOTES_v0.1.0-alpha.md` | Fixed GitHub URLs to kin0kaze23 |

### Tag

| Tag | Commit | Notes |
|-----|--------|-------|
| v0.1.0-alpha | 361aa87 | Deleted and recreated after URL fixes |

---

## Commands Run

```bash
# Build verification
swift build --target PulseCore          # PASS
swift build --target PulseCLI           # PASS
swift build --product pulse             # PASS

# Test verification
swift test --filter "PulseCoreTests|PulseCLITests"  # 74 tests, 0 failures

# Clean clone verification (separate directory)
git clone /path/to/local/repo pulse-alpha-test
cd pulse-alpha-test
git checkout v0.1.0-alpha
swift build --product pulse
.build/debug/pulse --help               # PASS
.build/debug/pulse analyze              # PASS
.build/debug/pulse clean --profile xcode --dry-run  # PASS
```

---

## What Ships in v0.1.0-alpha

### Commands
- `pulse analyze` — Scan all profiles, show reclaimable space
- `pulse clean --dry-run` — Preview cleanup for all profiles
- `pulse clean --profile <name> --dry-run` — Preview cleanup for specific profile
- `pulse clean --profile <name> --apply` — Execute cleanup (requires "yes" confirmation)
- `pulse --help` — Show help
- `pulse --version` — Show version

### Supported Profiles
- `xcode` — DerivedData, Archives, DeviceSupport, Simulators
- `homebrew` — Download cache, old formulae/casks
- `node` — npm cache, Yarn cache, pnpm store

### Safety
- Preview-first: dry-run is the default
- Confirmation required: `--apply` requires typing "yes"
- Protected paths: system paths, user data, app bundles cannot be deleted
- 74 tests passing

---

## Unresolved Issues

1. **App linker error**: The `Pulse` app target (MemoryMonitor) fails to link independently due to SwiftUI linking. Pre-existing, unrelated to CLI release.

2. **No `--yes` flag for scripting**: Cannot be automated in CI or pipelines. Known limitation.

3. **`--version` hardcoded**: Shows "0.1.0-alpha" regardless of git tag.

4. **Homebrew threshold**: Caches below 50 MB won't appear in output. Correct behavior but may confuse users.

5. **`system` profile exists without CLI support**: App-level items (Trash, browser caches, system caches) use `.system`. Not visible in CLI output yet.

---

## External Alpha Launch Recommendation

**Launch is approved.** All gates pass:

1. profileLabel() fixed — no more fragile path matching
2. Clean-room verified — all three commands pass from a clean clone
3. README tightened — install instructions, profiles, sample output, limitations, feedback
4. Release artifacts ready — issue template, release notes
5. 74 tests passing — no regressions

### Launch Steps

1. Push to GitHub: `git push origin phase0-hardening --tags`
2. Create GitHub release from tag v0.1.0-alpha using `RELEASE_NOTES_v0.1.0-alpha.md` content
3. Invite 10-15 macOS developers (Xcode/Homebrew/Node users)
4. Direct them to:
   ```bash
   git clone https://github.com/kin0kaze23/pulse.git
   cd pulse
   git checkout v0.1.0-alpha
   swift build
   .build/debug/pulse --help
   .build/debug/pulse analyze
   ```
5. Ask them to open an Alpha Feedback issue using the template
6. Collect feedback for 1 week
7. Decide next investment based on feedback

### What NOT to Do Before or During Alpha

- Do not add Docker support
- Do not add browser/system CLI profiles
- Do not start another big extraction
- Do not redesign the app
- Do not add "nice to have" CLI commands
- Do not try to perfect test coverage before alpha
- Do not add `--yes` flag during alpha (changes the contract mid-flight)
