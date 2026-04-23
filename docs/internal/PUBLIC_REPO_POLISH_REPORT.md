# Public Repo Polish Report

**Date:** 2026-04-23  
**Scope:** Public root cleanup, naming alignment, distribution trust  
**Goal:** Make the repo look intentionally curated for open-source users

---

## 1. Root Cleanup Plan

### Files/Folders That Should Stay in Root

| Item | Rationale |
|------|-----------|
| `README.md` | Main product documentation |
| `LICENSE` | MIT license (OSS requirement) |
| `CONTRIBUTING.md` | Contributor guidelines |
| `SECURITY.md` | Security reporting instructions |
| `Package.swift` | SPM manifest (required by Swift tooling) |
| `CHANGELOG.md` | Version history (OSS convention) |
| `ROADMAP.md` | Future plans (transparency signal) |
| `ARCHITECTURE.md` | System design (useful for contributors) |
| `docs/` | Documentation folder |
| `scripts/` | Install/uninstall scripts |
| `Sources/` | CLI source code |
| `Tests/` | Test suite |
| `extensions/` | Raycast extension |
| `screenshots/` | Visual assets for README |
| `Pulse.xcodeproj/` | Xcode project (standard for Swift repos) |
| `Pulse/` | Xcode resources (entitlements, Info.plist) |
| `Pulse.entitlements` | Part of Xcode project |
| `icon_generator.py` | **Move to scripts/** — build utility |

### Files/Folders That Should Move to docs/internal/

| Item | Rationale |
|------|-----------|
| `AGENTS.md` | Internal operator context ("Agent Instructions", "Repo Memory", "Dangerous Areas") — not for external users |
| `CLAUDE.md` | AI agent configuration — internal workflow detail |
| `NOW.md` | Current task tracking — internal project management |
| `EXTERNAL_ALPHA_LAUNCH_REPORT.md` | Internal launch report — not contributor-facing |
| `RELEASE_INTEGRITY_REPORT.md` | Internal audit report — useful for history but not root-facing |

### Files/Folders That Should Move to docs/releases/

| Item | Rationale |
|------|-----------|
| `RELEASE_NOTES_v0.1.0-alpha.md` | Superseded by GitHub Releases |
| `RELEASE_NOTES_v0.2.0.md` | Superseded by GitHub Releases |

### Files/Folders That Should Move to docs/features/

| Item | Rationale |
|------|-----------|
| `CAPABILITY_MATRIX.md` | Feature scope matrix — useful for contributors but too detailed for root |

### Files/Folders That Should Move to docs/guides/

| Item | Rationale |
|------|-----------|
| `GATES.md` | Quality gate definitions — internal process doc |

### Files/Folders That Should Be Removed from Public Repo

| Item | Rationale |
|------|-----------|
| `vault/projects/Pulse/` | Internal notes, evaluations, progress tracking, archived plans — contains local paths, private workflow assumptions, and internal decision records that should not be indexed or visible to outsiders |
| `.doppler.env` | Secrets management config — already in .gitignore but committed in history; remove from tree |

### Files/Folders That Should Be Renamed

| From | To | Rationale |
|------|-----|-----------|
| `MemoryMonitor/` | `PulseApp/` | Align with branding; README already says "PulseApp" but folder is still "MemoryMonitor" — confusing for contributors |

---

## 2. Expected Final Root Structure

After cleanup, the root should look like:

```
Pulse/
├── .github/               # CI, issue templates, CODEOWNERS
├── .gitignore
├── ARCHITECTURE.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── Package.swift
├── README.md
├── ROADMAP.md
├── SECURITY.md
├── docs/                  # Internal docs, features, releases, guides
├── extensions/            # Raycast extension
├── scripts/               # Install/uninstall scripts
├── screenshots/           # Visual assets
├── Sources/               # PulseCLI, PulseCore
├── Tests/                 # PulseCoreTests, PulseCLITests
├── Pulse.xcodeproj/       # Xcode project
├── Pulse/                 # Xcode resources
└── PulseApp/              # SwiftUI menu bar app (renamed from MemoryMonitor)
```

**What's removed from root:** AGENTS.md, CLAUDE.md, NOW.md, EXTERNAL_ALPHA_LAUNCH_REPORT.md, RELEASE_INTEGRITY_REPORT.md, RELEASE_NOTES_*.md, CAPABILITY_MATRIX.md, GATES.md, icon_generator.py, vault/, .doppler.env

---

## 3. GitHub Presentation Settings

| Setting | Current | Recommended |
|---------|---------|-------------|
| Description | "The safer, more developer-specific cleanup and machine audit tool for macOS" | ✅ Keep as-is — strong and accurate |
| Website | None | https://github.com/kin0kaze23/pulse |
| Topics | None | `macos` `swift` `cli` `developer-tools` `cleanup` `xcode` `homebrew` `nodejs` `raycast` `open-source` |
| Social preview image | None | Generate from README screenshots (dashboard or artifacts output) |
| Default branch | `phase0-hardening` | `main` — phase0-hardening sounds internal |
| Release source | `phase0-hardening` | `main` — releases should come from default branch |
| License | MIT (detected) | ✅ Correct |
| Code of Conduct | None | Add CODE_OF_CONDUCT.md (Contributor Covenant) |

---

## 4. Distribution Trust Checks

### 4.1 README Alignment

| Check | Status | Action |
|-------|--------|--------|
| Version in README matches release | ✅ README says v0.2.1 via git tag | No action needed |
| "85 passing" test count | ⚠️ Will drift | Change to "All tests passing" |
| Commands listed match actual commands | ✅ All 6 commands present | No action needed |
| Safety model described accurately | ✅ Matches implementation | No action needed |
| Install instructions match tap | ✅ `brew tap kin0kaze23/pulse` | No action needed |
| Links to stale branches | ⚠️ References `phase0-hardening` in releases | Fix by cutting releases from `main` |

### 4.2 Release Notes Alignment

| Check | Status | Action |
|-------|--------|--------|
| v0.2.1 release notes match actual changes | ✅ Changelog accurate | No action needed |
| v0.2.1 release assets match formula SHA | ✅ Verified | No action needed |
| No references to stale versions | ⚠️ v0.2.0 notes still in root | Move to docs/releases/ |

---

## 5. Public Repo Professionalism

### 5.1 Files to Add

| File | Purpose |
|------|---------|
| `CODE_OF_CONDUCT.md` | Contributor Covenant v2.1 — standard for OSS projects |
| `.github/CODEOWNERS` | Already exists — verify content is correct |
| `.github/ISSUE_TEMPLATE/` | Already exists (4 templates) — verify minimal and clean |
| `.github/PULL_REQUEST_TEMPLATE.md` | Already exists — verify outsider-focused |

### 5.2 Files to Verify

| File | Check | Status |
|------|-------|--------|
| `SECURITY.md` | Has reporting instructions and supported versions | ✅ Has disclosure process |
| `CONTRIBUTING.md` | Focused on outsiders, not internal workflow | ⚠️ Contains internal phase references — needs cleanup |
| `CODEOWNERS` | Lists correct maintainers | ✅ kin0kaze23 |

---

## 6. Risks

| Risk | Mitigation |
|------|------------|
| Moving `vault/` loses internal history | History preserved in git; can be restored if needed |
| Renaming `MemoryMonitor/` breaks Xcode project | Xcode project references will need updating (automated via Package.swift) |
| Changing default branch from `phase0-hardening` to `main` | GitHub will redirect old URLs; existing clones may need `git fetch` |
| Moving release notes to `docs/releases/` | GitHub Releases remains the canonical source |
| Removing `AGENTS.md` from root | Internal agents can still find it in `docs/internal/` |

---

## 7. Recommendation

**✅ Ready for broader external distribution after these changes.**

The core product is solid, the install path works, and the safety model is well-documented. The remaining gap is purely cosmetic — the public root exposes too much internal workflow. After the cleanup pass, the repo will look like a deliberately published OSS product rather than a live working tree.

**Priority order:**
1. Remove `vault/` and `.doppler.env` (security/privacy)
2. Rename `MemoryMonitor/` → `PulseApp/` (branding)
3. Move internal docs out of root (professionalism)
4. Set default branch to `main` (distribution)
5. Add CODE_OF_CONDUCT.md (professionalism)
6. Add GitHub topics and social preview (discovery)

---

*Report generated: 2026-04-23*
*All changes are reversible via git history.*
