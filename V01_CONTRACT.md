# Pulse v0.1 Execution Contract

> Frozen 2026-04-13. No scope changes without explicit approval.

## Product Promise

Pulse helps macOS developers safely reclaim disk space from developer junk and system/tooling bloat with preview-first cleanup.

## Target User

macOS developers who use Xcode, Node.js, Docker, Homebrew, and browsers on their daily driver Mac, and who periodically need to reclaim disk space from accumulated build artifacts, caches, and tooling junk.

NOT target users: general Mac consumers, server administrators, Linux users, security-conscious users looking for malware scanners.

## In-Scope (v0.1 Alpha)

### PulseCore
- cleanup engine (scan + apply)
- safety validation (protected paths, deny-list)
- dry-run/apply logic
- result model (what was cleaned, what was skipped, why)

### PulseCLI (exactly 4 commands)
- pulse analyze
- pulse clean --dry-run
- pulse clean --profile <name> --dry-run
- pulse clean --profile <name> --apply

### PulseApp
- visual shell over PulseCore (preview, apply, results)
- retains existing monitoring features (memory, CPU, disk) but these are not the v0.1 focus

### Cleanup Profiles (v0.1 Alpha -- the smallest safe slice)

Included:
- Xcode: DerivedData, Archives, Device Support, simulators
  - Rationale: highest GB reclaimed, lowest risk (all regenerate)
  - Verified: these paths are always caches, never user data

- Homebrew: cache, old versions
  - Rationale: safe (brew cleanup is idempotent), moderate GB reclaimed
  - Verified: brew handles its own safety

Deferred to v0.2:
- Node.js (npm/yarn/pnpm caches, node_modules)
  - Reason: project-local node_modules cleanup is risky. Deleting a node_modules inside an active project breaks builds. Global caches are safe, but the risk/reward is poor for v0.1 alpha.
  - Will return with explicit path scoping (only global caches, never project directories).

- Docker (stopped containers, dangling images, system prune)
  - Reason: docker system prune is too broad. It deletes networks, volumes, and build cache. A developer with stopped containers they intend to restart will lose work.
  - Will return with granular options (prune images only, prune volumes only, etc.).

- Browser caches (Safari, Chrome, Firefox)
  - Reason: lower value for the developer-focused wedge. Browser caches are small relative to Xcode/DerivedData. Risk of deleting active session data.
  - Will return as a separate profile in v0.2.

- System cleanup (logs, temp files, font caches)
  - Reason: lowest value, highest variance. System logs may be needed for debugging. Font caches are small.
  - Will return as a "general maintenance" profile in v0.2.

## Out-of-Scope (v0.1)

- Security scanner as a core feature (code stays, hidden from messaging)
- "Mac optimizer" positioning or language
- Linux or cross-platform support
- "pulse doctor" command
- Health score as a primary feature
- System monitoring redesign (memory, CPU, disk gauges stay as-is)
- Scheduled cleanup
- Auto-updates / Sparkle
- App Store submission
- Localization
- Additional CLI commands beyond the 4 defined
- Plugin architecture
- CoreML / AI features
- node_modules cleanup (project-local)
- Docker system prune
- Browser cache cleanup
- System log/temp cleanup

## Safety Guarantees

These are promises the code actually enforces, not aspirational statements.

1. Preview-first: no deletion without a dry-run that shows every path and size to be affected. The user must explicitly confirm before any deletion occurs.

2. Protected paths (deny-list): the following paths and their subdirectories CANNOT be deleted by any cleanup operation:
   - /System, /usr, /bin, /sbin, /var, /etc, /dev, /tmp, /private
   - /Library (system-level, not ~/Library)
   - /Applications
   - ~/Documents, ~/Desktop, ~/Downloads (the directories themselves, not individual files within them)
   - Any path ending in .app (app bundles)
   - The user's home directory itself
   VERIFIED: Tested in SafetyFeaturesTests against the actual implementation.

3. Size limit: maximum 100GB per cleanup operation. If the total exceeds this, the operation is rejected.
   VERIFIED: Code exists in ComprehensiveOptimizer. To be verified in PulseCore extraction.

4. Trash-based deletion (with exception): cleanup items are moved to Trash where technically feasible. EXCEPTION: certain cache directories (e.g., DerivedData) may be deleted directly if Trash semantics are unreliable for directory-level moves. Where direct deletion is used, this will be explicitly documented in the dry-run output.
   VERIFIED: LIMITATIONS.md acknowledges mixed deletion strategy. This contract does not overpromise.

5. In-use file detection (best-effort): the cleanup engine attempts to skip files currently open by any process. This is best-effort -- it uses file handle inspection which may not catch all cases. Files that are in use at the moment of deletion may fail with a filesystem error. This is safe (the file is not deleted) but should not be presented as a guarantee.
   VERIFIED: Code review of existing implementation. Phrased as best-effort in all user-facing text.

6. Whitelist: 60+ system processes cannot be auto-killed. This applies to the process management feature, not cleanup.
   VERIFIED: SafetyFeaturesTests cover this.

7. No silent deletions: every operation requires explicit confirmation. The dry-run is mandatory before apply. The CLI requires y/n confirmation for --apply. The app requires a confirmation dialog.

8. Test coverage: safety-critical path validation is tested against the real implementation, not a duplicated helper.
   VERIFIED: To be fixed in Phase 0.

## What "Safe" Means for v0.1 Alpha

Safe means:
- The user sees exactly what will be deleted before it happens
- The user explicitly confirms before any deletion
- System paths, user data directories, and app bundles cannot be deleted
- If something goes wrong during deletion, the operation stops (no cascading failures)
- The user can recover deleted items from Trash (where Trash-based deletion is used)

Safe does NOT mean:
- Zero risk of data loss (user could confirm deletion of something they later regret)
- Perfect detection of in-use files (best-effort only)
- Protection against user error (if the user explicitly confirms a bad cleanup, it happens)
- Protection against edge cases in macOS filesystem behavior

## Alpha Exit Criteria

v0.1 alpha is considered complete when ALL of the following are true:

1. External install: a person other than the author can clone the repo and build from scratch with zero errors
2. CLI works: pulse analyze and pulse clean --profile xcode --dry-run produce correct output on a fresh Mac
3. App works: PulseApp launches, shows PulseCore-backed preview, and completes a cleanup without crashing
4. Zero destructive bugs: no reports of accidental protected-path deletion, no data loss beyond what was explicitly confirmed
5. 10 external testers: 10 different people (not the author) have run pulse analyze on their machine and completed at least one dry-run
6. Test credibility: SafetyFeaturesTests tests the actual implementation, not a duplicated helper
7. Build reproducibility: swift build succeeds on a clean clone with no prerequisites beyond Xcode command-line tools
8. Documentation accuracy: README, CAPABILITY_MATRIX.md, and LIMITATIONS.md agree on what is built and what is not
9. Concurrency safety: no crashes from @Published updates on background threads (verified by Phase 0.5 completion)

## Definition of Done (per phase)

- All acceptance criteria met
- No new compiler warnings
- swift test passes with zero failures
- Code reviewed by at least one person other than the author (for Phase 1+)
- Docs updated to reflect current state
- Phase-end proof report written (see V01_PLAN.md for format)
- Explicit go/no-go decision recorded
