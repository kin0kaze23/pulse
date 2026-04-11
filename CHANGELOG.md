# Changelog

All notable changes to Pulse will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Historical metrics service with 24h/7d trend analysis
- Cleanup confirmation view with itemized preview
- Disk explorer tree view
- Smart suggestions engine with contextual recommendations
- Smart trigger monitor for event-based automation
- Automation scheduler for recurring tasks
- Large file finder with scan results
- Quiet hours manager for notifications
- Browser extension scanner (Safari, Chrome, Firefox)
- Cron job scanner
- Time Machine local snapshot management
- Permissions diagnostics view
- Onboarding permission flow
- Action toast view for operation feedback
- Skeleton loading views
- Cleanup stats view

### Changed
- Comprehensive optimizer replaced legacy memory optimizer
- Health score service with trend tracking and grade system
- Menu bar popover redesigned with Vitality Orb
- Dashboard redesigned with bento grid layout and 9 tabs

---

## [1.2.0] - 2026-04-11

### Added
- **GitHub Actions CI/CD** — Automated build and test on push/PR to main
  - `swift build` verification on every commit
  - `swift test` execution on every PR
  - Build badge for README
- **DesignSystem Color Token Consolidation** — Centralized `ColorPalette` struct
  - Health score colors: excellent (#30D158), good (#0A84FF), fair (#FFD60A), poor (#FF9F0A), critical (#FF453A)
  - Background tokens: card, elevated, overlay (dark-mode safe via opacity)
  - Text tokens: primary, secondary, tertiary
  - Status colors with dark-mode safe opacity variants
- **Dark Mode Audit** — Ensured all colors render correctly in both light and dark modes
  - Replaced raw `Color.green/.red/.orange/.yellow/.blue` with `DesignSystem.ColorPalette` references
  - Used `.opacity()` variants for backgrounds to ensure proper contrast
  - Used `.foregroundStyle(.primary)` / `.foregroundStyle(.secondary)` where appropriate
  - Updated 12+ view files: HealthScoreView, HealthView, MemoryGaugeView, BatteryThermalView, SecurityView, DashboardView, MenuBarLiteView, ProcessListView, DiskView, CPUView, AutoKillView, SmartSuggestionsView
- **README Overhaul**
  - GitHub Actions CI badge at top
  - Comprehensive Features section
  - Safety First section highlighting Phase 1 safety fixes
  - Screenshot section with placeholder descriptions and layout instructions
  - Installation instructions (build from source)
  - Comparison table with Stats, iStat Menus, and CleanMyMac
  - Contributing section with build/test instructions
  - Updated roadmap to reflect completed phases
- **CHANGELOG.md** — Full milestone history following Keep a Changelog format

### Changed
- Updated `Color.score()` to use semantic ColorPalette.Health colors
- Updated `Color.battery()` references to use ColorPalette
- Updated health score display in HealthScoreView and HealthView to use centralized color mapping
- Updated thermal color mappings to use ColorPalette.Health
- Updated memory/CPU/disk gauge colors across all views
- Updated status tile colors in HealthView
- Updated process list SAFE badge colors
- Updated security view monitoring indicator colors
- Updated auto-kill view threat level colors
- Updated dashboard permission toast colors

### Fixed
- Color contrast issues in dark mode for status badges and backgrounds
- Inconsistent color usage across view files (now centralized through DesignSystem)

---

## [1.1.0] - 2026-03-27

### Added
- Health score with A-F grading system
- Vitality Orb animation in menu bar popover
- Bento grid dashboard layout
- Staggered entrance animations
- Haptic feedback for interactions
- Permission diagnostics screen
- Security scanner with real-time monitoring
- Developer profiles for cleanup (Xcode, Docker, Node.js, Homebrew, Python, Rust, Go)
- Process manager with kill functionality
- Auto-kill guard for runaway processes
- Protected process whitelist (60+ system processes)
- Smart suggestions engine
- Package manager cache scanning
- Battery and thermal monitoring
- Temperature monitoring via SMC/IOKit
- Network monitoring via getifaddrs

### Changed
- Redesigned dashboard with 9-tab interface
- Updated menu bar popover with premium design
- Improved optimizer with itemized cleanup plans
- Enhanced security scanner with threat detection

### Fixed
- Various UI consistency issues
- Memory monitoring accuracy improvements

---

## [1.0.0] - 2026-03-22

### Added
- **Core monitoring** — Memory (mach VM APIs), CPU (host_processor_info), Disk (FileManager), Network (getifaddrs)
- **Cache cleanup engine** — Xcode, Docker, Homebrew, npm, browser caches
- **Security scanner** — LaunchAgents, LaunchDaemons, login items, crontab detection
- **Safety features (Phase 1)**
  - Protected system paths deny-list (/System, /usr, /bin, /sbin, etc.)
  - In-use file detection (skips open files)
  - App bundle protection
  - User data protection (~/Documents, ~/Desktop, ~/Downloads)
  - 100GB max per cleanup operation
  - Preview before deletion
  - Process whitelist for auto-kill
  - Graceful kill sequence (SIGTERM → SIGKILL)
  - Confirmation dialogs for large cleanups
- **Test coverage** — SafetyFeaturesTests, AppSettingsTests, SecurityScannerTests, DeveloperProfilesTests
- **Menu bar app** — Memory percentage display with color-coded pressure
- **Basic dashboard** — Memory, CPU, Disk views
- **Design system** — Spacing scale, typography, corner radius, animation presets, color semantics
- **Documentation** — ARCHITECTURE.md, SECURITY.md, CAPABILITY_MATRIX.md, LIMITATIONS.md, ROADMAP.md

---

## Versioning Notes

- **1.x.x** — Pre-release, feature-complete monitoring and cleanup
- **2.0.0** — Planned: Signed, notarized distribution with Sparkle auto-updates

## Release Process

1. Update version in this CHANGELOG
2. Update version in Brand.swift
3. Tag release: `git tag -a v1.2.0 -m "Release v1.2.0"`
4. Push tag: `git push origin v1.2.0`
5. CI will build and verify automatically
