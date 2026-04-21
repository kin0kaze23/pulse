# External Alpha Launch Surface Review

**Reviewer:** Hermes Agent
**Date:** 2026-04-18
**Commit:** bf79787 (latest, includes EXTERNAL_ALPHA_LAUNCH_REPORT.md)
**Tag:** v0.1.0-alpha (361aa87)
**Scope:** Verify launch readiness for 10-15 person controlled external alpha

---

## Verdict: GO (with 1 minor doc gap)

The release surface is ready for controlled external alpha. The tag points to a stable
commit, install instructions are reproducible, scope is honest and limited to 3 profiles,
safety expectations are clearly communicated, and all 74 tests pass. One minor documentation
gap noted (README CLI section lacks tag reference) but not blocking since the RELEASE_NOTES
and launch report contain the correct path.

---

## 1. Release Points Testers to Stable Tag, Not Drifting Branch

| Check | Result | Evidence |
|-------|--------|----------|
| Tag v0.1.0-alpha exists | PASS | Tag at commit 361aa87, deleted and recreated after URL fixes |
| RELEASE_NOTES points to tag | PASS | `**Tag:** v0.1.0-alpha`, install says `git checkout v0.1.0-alpha` |
| Feedback template references tag | PASS | `**Tag / commit:** [v0.1.0-alpha / other]` (updated from branch reference) |
| Launch report uses tag | PASS | `git checkout v0.1.0-alpha` in the 5-step alpha invite instructions |
| GitHub URLs updated to correct org | PASS | All 3 files updated: kin0kaze23 (not jonathannugroho) |
| README main install lacks tag | NOTE | "Install from Source" section says `git clone`, `swift build -c release`, `open .build/release/Pulse` -- no tag reference, builds the app not the CLI |
| README CLI section lacks tag | NOTE | "Build" subsection says just `swift build` -- no `git checkout v0.1.0-alpha` |

**Assessment: PASS with note** -- The authoritative alpha install path (RELEASE_NOTES + launch report) correctly references the tag. The README CLI section doesn't reference the tag, which means if main branch drifts, readers of only the README could get a different version. For controlled alpha where testers receive direct instructions with the RELEASE_NOTES path, this is acceptable. Should be fixed before public launch.

---

## 2. First-Time Install/Use Instructions Clear and Reproducible

| Check | Result | Evidence |
|-------|--------|----------|
| Clone command correct | PASS | `git clone https://github.com/kin0kaze23/pulse.git` |
| Tag checkout present | PASS | `git checkout v0.1.0-alpha` in RELEASE_NOTES and launch report |
| Single build step | PASS | `swift build` -- no dependency installation, no config, no key setup |
| Verification step included | PASS | `.build/debug/pulse --help` as final step |
| Clean clone verified | PASS | EXTERNAL_ALPHA_LAUNCH_REPORT.md documents clean clone flow with all 3 commands verified: `pulse --help`, `pulse analyze`, `pulse clean --profile xcode --dry-run` |
| All 3 CLI commands work | PASS | Verified in test output and live run |
| Build time reasonable | PASS | 12 seconds for full build (including app + CLI) |
| No platform ambiguity | PASS | Package.swift specifies `.macOS(.v14)` -- Sonoma or later required |

**Assessment: PASS** -- A macOS developer with Swift toolchain can clone, checkout tag, build, and verify in under 2 minutes. Clean clone flow was explicitly verified.

---

## 3. Release Surface Honest and Limited to xcode, homebrew, node

| Check | Result | Evidence |
|-------|--------|----------|
| CleanCommand supportedProfiles | PASS | Exactly 3 entries: xcode, homebrew, node |
| AnalyzeCommand allProfiles | PASS | Exactly 3: `[.xcode, .homebrew, .node]` |
| No CaseIterable iteration in CLI | PASS | grep for "CaseIterable" in PulseCLI/: 0 matches. Profiles are explicitly listed, not derived from enum. |
| No system/docker/browser in CLI | PASS | grep for "system", "docker", "browser" in PulseCLI/: 0 matches |
| README labels scope honestly | PASS | "This is the **alpha** release -- only three profiles are supported" |
| README labels app-only features | PASS | Docker, browser, system marked "(app only)" in features section |
| "What Pulse Will NOT Touch" section | PASS | Explicitly lists 5 categories of excluded items including "Other profiles: Docker, browser caches, system logs, Bun, pip, Go, Cargo" |
| Known limitations documented | PASS | 5 honest limitations including "Only 3 profiles" |
| Release notes list exclusions | PASS | "What's NOT Included" lists: Docker, browser, system, Bun, pip, Go, Cargo, scheduling, automation, telemetry, config files, concurrent cleanup |

**Assessment: PASS** -- Release surface is honest, tightly scoped, and clearly labeled. No overpromising. Future profiles (system was added to CleanupProfile enum but is not exposed in CLI).

---

## 4. Safety Expectations Clearly Communicated

| Check | Result | Evidence |
|-------|--------|----------|
| Release notes safety section | PASS | 4 safety guarantees listed: Preview-first, Confirmation required, Protected paths, Trash-first |
| "What Pulse Will NOT Touch" in README | PASS | 5 specific categories: project-local files, system-critical paths, user data, app bundles, other profiles |
| --apply requires "yes" confirmation | PASS | CleanCommand.runApply: prompts `Type 'yes' to confirm:`, cancels on any other input |
| No --force or --yes flag | PASS | Not in argument parser. Known limitation #2 in README |
| Protected paths documented | PASS | README explicitly lists `/System`, `/usr`, `/bin`, `/sbin` as protected; `~/Documents`, `~/Desktop`, `~/Downloads` as protected; `.app` files never deleted |
| Trash-first documented | PASS | Release notes: "Files go to Trash before permanent deletion (configurable)" |
| Dry-run is default | PASS | Release notes: "Dry-run is the default", README: "Preview cleanup (dry run)" shown before apply command |
| Feedback asks about trust | PASS | Alpha feedback template: "Did you trust it? [Yes / No / Unsure -- why?]" |

**Assessment: PASS** -- Safety expectations are over-communicated across README, release notes, CLI output, and feedback template. Testers will know exactly what the tool will and won't do before running it.

---

## 5. Ready for 10-15 Person Controlled External Alpha

| Check | Result | Evidence |
|-------|--------|----------|
| All PulseCore + PulseCLI tests pass | PASS | 74/74 tests, 0 failures. Verified live. |
| Build clean | PASS | `swift build` completes. Warnings are pre-existing (LargeFileFinder, AppUninstaller) and unrelated to CLI. |
| CLI runs on real machine | PASS | `pulse analyze` shows 2.1 GB reclaimable with correct profile labels |
| Unsupported profiles rejected cleanly | PASS | `pulse clean --profile docker --dry-run` returns error + supported list + usage |
| Feedback mechanism ready | PASS | .github/ISSUE_TEMPLATE/alpha_feedback.md with structured sections |
| Release notes ready | PASS | RELEASE_NOTES_v0.1.0-alpha.md with complete install, features, safety, limitations, feedback link |
| Launch plan documented | PASS | EXTERNAL_ALPHA_LAUNCH_REPORT.md with 7-step launch process and "What NOT to Do" guardrails |
| Tag points to stable commit | PASS | v0.1.0-alpha at 361aa87, recreated after URL fixes |

**Assessment: PASS** -- All gates pass. Ready for controlled alpha.

---

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| README CLI section doesn't reference tag | LOW | Alpha testers receive direct instructions with RELEASE_NOTES path. Fix before public launch. |
| `case system` exists in CleanupProfile enum | LOW | Not exposed in CLI (0 matches in PulseCLI source). Could confuse if someone inspects the enum directly. |
| AppUninstaller pre-existing test failure | NONE | Outside CLI scope, doesn't affect PulseCore or PulseCLI. |
| LargeFileFinder pre-existing warnings | NONE | Compiler warnings in app code, unrelated to CLI. |

---

## Blocking Issues

None. All checks pass.

---

## Recommendation

**LAUNCH NOW.**

The repo is ready for a 10-15 person controlled external alpha. The recommended launch sequence:

1. Push to GitHub: `git push origin phase0-hardening --tags`
2. Create GitHub release from tag v0.1.0-alpha using RELEASE_NOTES content
3. Invite 10-15 macOS developers (Xcode/Homebrew/Node users) via direct message with:
   - Link to GitHub release
   - 5-step install path (clone, checkout tag, build, verify)
   - Link to alpha feedback template
4. 1-week feedback window
5. Triage feedback, decide next investment

Do NOT before or during alpha:
- Add Docker, browser, or system CLI profiles
- Add --yes or --force flags
- Start another big extraction
- Redesign the app
- Add "nice to have" CLI commands

The minor README doc gap (CLI section missing tag reference) should be fixed as a follow-up but does not block the launch since alpha testers will receive explicit instructions with the correct tag.
