---
status: active
task: Preparing external alpha launch
lane: FAST
objective: Ship v0.2.0 with complete CLI, Homebrew tap, and hardened safety model
blockers: [TAP_TOKEN secret needed for auto-tap-updates in CI]
last_decision: 2026-04-23 — Tier 2 complete, ready for release
next_step: Push v0.2.0 tag to trigger release workflow
rollback: git revert per-commit
updated: 2026-04-23
---

# NOW - Pulse

> Updated by /checkpoint. Do not edit manually unless /checkpoint is unavailable.

## Current Task
v0.2.0 Release — External Alpha Prep

## Status
active

## Last Gate
Build: PASS (0 errors, 0 warnings)
Test: PASS (85 tests, 0 failures — PulseCoreTests + PulseCLITests)

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
- [x] Homebrew formula with SHA256
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

## Remaining Before Alpha Launch

### Distribution
- [ ] Create TAP_TOKEN secret for auto-tap formula updates (needs PAT with write access to homebrew-pulse)
- [ ] Push v0.2.0 tag to trigger release workflow

## Outstanding Phase 0 Items (Low Priority)
- [ ] Update CI workflow with Xcode build verification
- [ ] Rewrite SafetyFeaturesTests to test real implementation

---

*Last updated: 2026-04-23*
*v0.2.0 Release — Ready to tag*
