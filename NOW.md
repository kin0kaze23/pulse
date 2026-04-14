# NOW - Pulse

> Updated by /checkpoint. Do not edit manually unless /checkpoint is unavailable.

## Current Task
Phase 0: Repo Hardening

## Status
active

## Last Gate
Build: PASS (swift build successful)
Test: PASS (verify current test count after Phase 0 changes)

## Immediate Next Steps

### Phase 0: Repo Hardening (In Progress)
- [x] Remove Pulse.app binary from git tracking
- [x] Add Pulse.app/ to .gitignore
- [x] Remove personal bundle IDs from source (SecurityScanner, AppUninstaller, ComprehensiveOptimizer)
- [x] Remove personal bundle IDs from tests (SafetyFeaturesTests, AppUninstallerTests, SecurityScannerTests)
- [x] Replace screenshot prose with real image embeds in README
- [x] Delete OPEN_SOURCE_READINESS.md
- [x] Update ROADMAP.md milestones
- [ ] Update NOW.md (this file)
- [ ] Update CAPABILITY_MATRIX.md with v0.1 alpha scope
- [ ] Update README.md version and scope
- [ ] Update CI workflow (add caching, Xcode build verification)
- [ ] Rewrite SafetyFeaturesTests to test real implementation

### Phase 0.5: Concurrency Safety (Planned)
- [ ] Add @MainActor to data models and settings (Batch 1)
- [ ] Add @MainActor to monitoring services (Batch 2)
- [ ] Add @MainActor to coordinator and optimizer (Batch 3)

### After Phase 0.5
- Phase 1: PulseCore extraction
- Phase 2: PulseCLI v0.1
- Phase 3: PulseApp shell
- Phase 4: External alpha validation

## Deliverables Summary

### Phase 0 Target
- Clean git history (no binary, no personal IDs)
- Real screenshots in README
- Reconciled documentation
- Test credibility (SafetyFeaturesTests hits real implementation)
- CI workflow verifies both SPM and Xcode builds

---

*Last updated: 2026-04-14*
*Phase 0: Repo Hardening — In Progress*
