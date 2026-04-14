# Pulse

> Keep your Mac in flow

[![CI](https://github.com/jonathannugroho/pulse/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathannugroho/pulse/actions/workflows/ci.yml)
![macOS](https://img.shields.io/badge/macOS-14.0+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue)

A native macOS menu bar app for system health monitoring and cache cleanup.

---

## What Pulse Does

Pulse is a **system monitoring dashboard** with **cache cleanup automation** for macOS developers.

---

## Features

### System Monitoring
- **Memory** — Real-time memory pressure, swap usage, and breakdown (mach VM APIs)
- **CPU** — Per-core utilization, user/system/idle split, top processes
- **Disk** — Volume usage, pressure gauges, and reclaimable space
- **Network** — Interface-level send/receive statistics
- **Battery** — Percentage, cycle count, health, time remaining
- **Thermal** — Thermal state monitoring and temperature (where available)

### Health Score
- **A-F Grading** — Composite health score (0-100) based on memory, CPU, disk, and thermal metrics
- **Trend Tracking** — 24-hour and 7-day trend analysis with delta indicators
- **Score Breakdown** — Transparent view of what's impacting your score
- **Actionable Recommendations** — One-click fixes for common issues

### Cache Cleanup
- **Xcode** — DerivedData, Archives, Device Support, simulators
- **Docker** — Stopped containers, dangling images, system prune
- **Node.js** — npm cache, yarn cache, node_modules
- **Homebrew** — Cache, old versions
- **Browsers** — Safari, Chrome, Firefox caches
- **System** — Icon services, font caches, logs
- **Time Machine** — Local snapshots
- **Package Managers** — pip, cargo, go module caches

### Process Management
- **Top Processes** — View and sort by memory or CPU
- **Kill Processes** — SIGTERM → SIGKILL with confirmation
- **Auto-Kill Guard** — Configurable thresholds for runaway processes
- **Protected Whitelist** — 60+ system processes cannot be killed
- **Safe-to-Close Badges** — Visual indicators for non-critical processes

### Security Scanner
- **Persistence Detection** — LaunchAgents, LaunchDaemons, login items, crontab
- **Browser Extensions** — Safari, Chrome, Firefox extension audit
- **Real-Time Monitoring** — 60-second threat scan cycle
- **Permission Diagnostics** — FDA, Accessibility, Apple Events status
- **Suspicious Process Scanner** — Heuristic analysis of running processes

### Developer Tools
- **Profile-Based Cleanup** — Pre-configured profiles for Xcode, Docker, Node.js, Homebrew, Python, Rust, Go
- **Custom Commands** — Add your own cleanup shell commands
- **Smart Suggestions** — Context-aware cleanup recommendations

### User Experience
- **Menu Bar App** — Lightweight, always-available monitoring
- **Vitality Orb** — Animated centerpiece showing overall health at a glance
- **Bento Grid Dashboard** — 9-tab dashboard with health, memory, system, caches, cleaner, developer, security, history, and disk explorer
- **Dark Mode Support** — Fully adaptive UI with semantic color tokens
- **Staggered Animations** — Purposeful, comprehension-improving transitions
- **Haptic Feedback** — Tactile response for key interactions

---

## Screenshots

### Menu Bar
![Menu bar](screenshots/pulse-01-onboarding.png)

### Dashboard - Health
![Health dashboard](screenshots/health-trend-01-dashboard.png)

### Dashboard - Security
![Security status](screenshots/pulse-02-security-status.png)

### Permission Diagnostics
![Permission diagnostics](screenshots/pulse-04-permissions-view.png)

---

## Safety First

Pulse was built with safety as the primary concern. Phase 1 introduced critical safety fixes that protect your system:

- **Protected System Paths** — `/System`, `/usr`, `/bin`, `/sbin`, `/Applications`, and other critical directories are on a deny-list and cannot be deleted
- **In-Use File Detection** — Files currently open by any process are automatically skipped during cleanup
- **App Bundle Protection** — `.app` bundles are never deleted
- **User Data Protection** — `~/Documents`, `~/Desktop`, `~/Downloads` are protected from accidental cleanup
- **Size Limits** — Maximum 100GB per cleanup operation to prevent runaway deletions
- **Preview Before Delete** — Every cleanup shows an itemized list with sizes before confirmation
- **Process Whitelist** — 60+ critical system processes cannot be terminated, even by the auto-kill guard
- **Graceful Kill Sequence** — SIGTERM first, SIGKILL only after timeout — no brutal force by default
- **Confirmation Dialogs** — Large cleanups require explicit extra confirmation

See [SECURITY.md](SECURITY.md) for the full security policy and threat model.

---

## Quick Start

### Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ toolchain
- 50 MB disk space

### Install from Source

```bash
git clone https://github.com/jonathannugroho/pulse.git
cd pulse
swift build -c release

# The built executable is at .build/release/Pulse
# Drag to Applications folder or run directly
open .build/release/Pulse
```

### Run Tests

```bash
swift test
```

### First Launch

On first launch, Pulse will:
1. Open the dashboard window
2. Add itself to the menu bar
3. Begin monitoring system metrics

**Optional permissions:**
- **Full Disk Access** — Enables deeper security scans (Settings → Privacy & Security)
- **Accessibility** — Enables accessibility permission detection (Settings → Privacy & Security)
- **Notifications** — Enables memory threshold alerts

---

## Usage

### Menu Bar

Pulse lives in your menu bar for quick access:

- **Memory %** — Current memory pressure (color-coded)
- **Click** — Open popover with quick stats and Vitality Orb
- **Right-click** — Full menu with actions

### Dashboard

The main window has 9 tabs:

| Tab | Purpose |
|-----|---------|
| Health | Overview, health score, recommendations |
| Memory | Detailed memory stats and history |
| System | CPU, Disk, Network, Battery |
| Caches | Package manager cache sizes |
| Cleaner | Process list, cleanup, history |
| Developer | Dev tool profiles and actions |
| Security | Persistence scanner |
| History | Metric charts over time |
| Disk Explorer | Tree view of disk usage |

---

## Comparison with Other Tools

| Feature | Pulse | Stats | iStat Menus | CleanMyMac |
|---------|-------|-------|-------------|-------------|
| **Price** | Free (MIT) | Free (MIT) | $12 | $40/yr |
| **Menu Bar** | ✅ | ✅ | ✅ | ❌ |
| **Dashboard** | ✅ | ❌ | ✅ | ✅ |
| **Health Score** | ✅ (A-F) | ❌ | ✅ | ✅ |
| **Cache Cleanup** | ✅ (itemized) | ❌ | ❌ | ✅ |
| **Security Scan** | ✅ | ❌ | ❌ | ✅ |
| **Process Kill** | ✅ | ❌ | ✅ | ✅ |
| **Auto-Kill Guard** | ✅ | ❌ | ❌ | ❌ |
| **Developer Profiles** | ✅ | ❌ | ❌ | ❌ |
| **Open Source** | ✅ | ✅ | ❌ | ❌ |
| **macOS 14+** | ✅ | ✅ | ✅ | ✅ |

---

## Development

### Build & Run

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Run specific tests
swift test --filter SafetyFeaturesTests
```

### Project Structure

```
Pulse/
├── MemoryMonitor/Sources/
│   ├── App.swift                 # Main entry, menu bar, windows
│   ├── Models/                   # Data models and settings
│   ├── Services/                 # Monitors, scanners, optimizers
│   ├── Views/                    # SwiftUI views and components
│   └── Utilities/                # Design system, helpers
├── Tests/                        # Unit tests
├── .github/workflows/ci.yml      # CI pipeline
├── Package.swift
└── README.md
```

### Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

### Contributing

Contributions are welcome! Here's how to get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run the test suite: `swift test`
5. Ensure the build passes: `swift build`
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

**Code Quality Gates:**
- All PRs must pass `swift build` (typecheck + build)
- All PRs must pass `swift test` (no new test failures)
- New features should include tests where applicable

**Areas that need help:**
- [ ] Xcode project for proper entitlements/signing
- [ ] Notarization workflow
- [ ] Sparkle auto-updates
- [ ] Historical charts (Swift Charts integration)
- [ ] Disk treemap visualization
- [ ] More cleanup profiles
- [ ] Unit test coverage

---

## Permissions

Pulse requests minimal permissions:

| Permission | Why | Required? |
|------------|-----|-----------|
| **Full Disk Access** | Security scanner can read protected directories | Optional |
| **Accessibility** | Detect apps with keyboard monitoring | Optional |
| **Apple Events** | Count browser tabs, manage apps | Optional |
| **Notifications** | Memory threshold alerts | Optional |

Check permission status in the **Security** tab.

---

## Troubleshooting

### Temperature shows 0°C

SMC-based temperature reading may not work on all Mac models, especially Apple Silicon (M1/M2/M3). This is a hardware limitation.

### Security scan shows "Limited detection"

Pulse needs Full Disk Access to read certain system directories. Enable it in System Settings → Privacy & Security → Full Disk Access.

### Login Items scan is incomplete

macOS Sonoma+ moved login items to System Settings, which Pulse cannot read. Check System Settings → General → Login Items manually.

### Docker cleanup fails

Requires Docker CLI at `/usr/local/bin/docker`. Install Docker Desktop or ensure Docker CLI is in PATH.

### Tests crash

Some tests require full app context. Run specific suites:
```bash
swift test --filter SafetyFeaturesTests  # Works
swift test --filter AppSettingsTests     # Works
```

---

## Roadmap

### Phase 1: Foundation ✅
- Core monitoring (memory, CPU, disk, network)
- Cache cleanup engine
- Security scanner
- Safety features (path validation, whitelists)
- Test coverage for safety features

### Phase 2: Polish ✅
- Truthful documentation (capability matrix, limitations)
- Permission diagnostics screen
- User onboarding flow

### Phase 3: Polish ✅
- GitHub Actions CI/CD pipeline
- DesignSystem color token consolidation
- Dark mode audit and semantic color palette
- README overhaul with CI badge and feature list
- CHANGELOG.md with full milestone history

### Phase 4: Distribution (Future)
- Xcode project for entitlements
- Code signing + notarization
- Sparkle auto-updates
- Historical charts (Swift Charts)
- App Store submission (if feasible)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Pulse learns from these open-source projects:

- **[Stats](https://github.com/exelban/stats)** — Menu bar monitoring (MIT)
- **[Objective-See tools](https://objective-see.com/)** — Security scanning techniques
- **[mac-cleanup](https://github.com/fwartner/mac-cleanup)** — Cleanup script inspiration

---

## Disclaimer

Pulse is provided "as is" without warranty. While safety features prevent accidental deletion of critical files, **all cleanup operations are permanent**. Ensure you have current backups before using cleanup features.

The authors are not responsible for data loss, system instability, or any damages resulting from use of this software.

---

*Last updated: April 11, 2026*
*Version: 1.2.0*
