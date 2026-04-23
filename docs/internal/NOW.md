---
status: active
task: External alpha launch with 10–15 macOS developers
lane: FAST
objective: Validate install trust, dry-run usage, and space reclaimed in controlled alpha
blockers: []
last_decision: 2026-04-23 — Release integrity verified, v0.2.1 is canonical
next_step: Launch external alpha, hold scope 1 week, collect feedback
rollback: git revert per-commit
updated: 2026-04-23
---

# NOW - Pulse

> Updated by /checkpoint. Do not edit manually unless /checkpoint is unavailable.

## Current Task
External Alpha Launch — 10–15 macOS developers, 1 week scope hold

## Status
active

## Last Gate
Build: PASS (0 errors, 0 warnings)
Test: PASS (85 tests, 0 failures — PulseCoreTests + PulseCLITests)
Release: PASS (v0.2.1, public repo, public tap, public assets)

## Completed

### Phase A: CLI Shipping Fixes ✅
- [x] Fix `pulse doctor --json` exit code — always exits 0, status in payload
- [x] Add `--yes` / `-y` / `--force` flags for CI/CD automation
- [x] Align JSON action labels between analyze and clean commands
- [x] Fix `--version` to read from git tag
- [x] Fix README — removed stale "No JSON output" limitation
- [x] Fix Pulse/PulseApp binary collision on case-insensitive filesystem

### Phase 0: Repo Hardening ✅
- [x] Remove Pulse.app binary from git tracking
- [x] Add Pulse.app/ to .gitignore
- [x] Remove personal bundle IDs from source and tests
- [x] Replace screenshot prose with real image embeds in README
- [x] Delete OPEN_SOURCE_READINESS.md
- [x] Update ROADMAP.md milestones

### Phase B: CLI Polish ✅
- [x] Non-TTY detection — ANSI colors disabled when piped/scripted
- [x] Progress indicator — "Pulse" banner before scan output
- [x] ASCII brand banner — shown when `pulse` runs with no args
- [x] Install script v2 — `--yes`, `--tag`, `--prefix` flags, tries brew first

### Tier 1: Distribution ✅
- [x] GitHub Actions release workflow (release-cli.yml)
- [x] Homebrew tap repo created (kin0kaze23/homebrew-pulse)
- [x] Homebrew formula auto-updates on new releases
- [x] TAP_TOKEN secret configured for auto-tap updates
- [x] README updated with brew install instructions

### Tier 2: Feature Expansion ✅
- [x] `pulse artifacts` — scan 16 artifact types from project directories
- [x] `pulse audit` — scan dev environment (simulators, taps, symlinks, toolchains)
- [x] Config file (`~/.config/pulse/config.json`) for scan paths, thresholds, exclusions
- [x] Auto JSON detection when output is piped (non-TTY)
- [x] Swift 6 Sendable conformance on all public types
- [x] TOCTOU race condition fix in CleanupEngine
- [x] Tightened /var/folders path validation
- [x] Fixed LargeFileFinder compiler warnings
- [x] Zero compiler warnings across entire codebase

### Release Integrity Pass ✅
- [x] Made pulse repo public (was private, returning 404)
- [x] Fixed tap README install command (`brew tap kin0kaze23/pulse`)
- [x] Fixed release workflow `homebrew-tap` parameter
- [x] Verified v0.2.1 release assets publicly accessible
- [x] Verified tap formula points to correct release
- [x] Verified doctor --json exit code semantics
- [x] Verified JSON action label alignment
- [x] Produced RELEASE_INTEGRITY_REPORT.md

## Do Not Start (Until Alpha Feedback)

### Commands
- [ ] `pulse config` — config file already works, CLI wrapper can wait
- [ ] `pulse history` — tracking over time
- [ ] `pulse compare` — before/after comparison

### Phase 3B Audits
- [ ] `pulse audit startup`
- [ ] `pulse audit disk-pressure`
- [ ] `pulse audit persistence`

### Other
- [ ] Interactive TUI
- [ ] Live monitoring dashboard
- [ ] Smart app uninstaller

## Alpha Metrics to Track

1. **Install success rate** — % of testers who can `brew install pulse` without errors
2. **Dry-run usage** — % who run `--dry-run` before `--apply`
3. **Trust signals** — Do users feel confident about what will be deleted?
4. **Confusion points** — Where do users get stuck or misunderstand output?
5. **Space reclaimed** — How much actual space do users reclaim?
6. **JSON scripting** — Any users leveraging `--json` output?

---

*Last updated: 2026-04-23*
*v0.2.1 — External Alpha Ready*
