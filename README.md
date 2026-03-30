# Pulse

> Keep your Mac in flow

A native macOS menu bar app for system health monitoring and cache cleanup.

![macOS](https://img.shields.io/badge/macOS-14.0+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue)

---

## What Pulse Does

Pulse is a **system monitoring dashboard** with **cache cleanup automation** for macOS developers.

**Core features:**
- 📊 **System Monitoring** — Memory, CPU, disk, network, battery, thermal metrics
- 🧹 **Cache Cleanup** — Xcode, Docker, Homebrew, npm, browser caches
- 📈 **Health Score** — A-F grade based on current system metrics
- 🔍 **Process Manager** — View and terminate high-resource processes
- 🔒 **Security Scanner** — Detect persistence items and suspicious startup entries
- 🛠️ **Developer Tools** — Profile-based cleanup for dev tooling

**What Pulse is NOT:**
- ❌ Not a memory booster (macOS manages memory automatically)
- ❌ Not a security suite (no malware scanning)
- ❌ Not an AI tool (rules-based automation only)
- ❌ Not a backup tool (deletions are permanent)

See [CAPABILITY_MATRIX.md](CAPABILITY_MATRIX.md) and [LIMITATIONS.md](LIMITATIONS.md) for detailed accuracy information.

---

## Screenshots

> TODO: Add screenshots of:
> - Menu bar with memory percentage
> - Dashboard Health tab
> - Memory tab with breakdown
> - Optimizer tab with cleanup preview
> - Security scanner results
> - Developer profiles

---

## Quick Start

### Requirements

- macOS 14.0 (Sonoma) or later
- 50 MB disk space
- Optional: Full Disk Access for security scanning

### Install

**Option 1: Build from source (recommended for testing)**

```bash
git clone https://github.com/jonathannugroho/pulse.git
cd pulse
swift build -c release

# The app will be at .build/release/Pulse
# Drag to Applications folder or run directly
open .build/release/Pulse
```

**Option 2: Download pre-built release** (coming soon)

1. Download `Pulse.app.zip` from Releases
2. Move to `/Applications`
3. Right-click → Open (first launch requires manual approval)

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

## Features

### System Monitoring

| Metric | Method | Accuracy |
|--------|--------|----------|
| Memory | mach VM APIs | ✅ Accurate |
| CPU | host_processor_info | ✅ Accurate |
| Disk | FileManager volumes | ✅ Accurate |
| Network | getifaddrs | ✅ Accurate |
| Battery | pmset, ioreg | ✅ Accurate |
| Thermal | ProcessInfo.thermalState | ✅ Accurate |
| Temperature | SMC via IOKit | ⚠️ Varies by Mac model |

### Cache Cleanup

Pulse can safely delete:

| Category | Examples | Safe? | Regenerates? |
|----------|----------|-------|--------------|
| Xcode | DerivedData, Archives, Device Support | ✅ Yes | ✅ Yes (as needed) |
| Docker | Stopped containers, dangling images | ✅ Yes | ❌ No |
| Node.js | npm cache, yarn cache, node_modules | ✅ Yes | ✅ Yes (npm install) |
| Homebrew | Cache, old versions | ✅ Yes | ❌ No |
| Browsers | Safari, Chrome, Firefox caches | ✅ Yes | ✅ Yes (browsing) |
| System | Icon services, font caches, logs | ✅ Yes | ✅ Yes |
| Time Machine | Local snapshots | ✅ Yes | ❌ No |
| iOS | Updates, backups | ⚠️ Review first | ❌ No |

**Safety features:**
- Preview before deletion
- Protected system paths (cannot delete /System, /usr, etc.)
- In-use file detection (skips open files)
- Size limits (100GB max per operation)
- Whitelist support

**Warning:** Deletions are permanent. Ensure you have backups before using cleanup features.

### Process Management

- View top processes by memory and CPU
- Kill individual processes (SIGTERM → SIGKILL)
- Auto-kill runaway processes (configurable thresholds)
- Protected whitelist (60+ system processes cannot be killed)

### Security Scanner

Scans for persistence mechanisms:

| Location | Scanned | Notes |
|----------|---------|-------|
| ~/Library/LaunchAgents | ✅ Yes | User-level startup items |
| /Library/LaunchAgents | ✅ Yes | System-level startup items |
| /Library/LaunchDaemons | ✅ Yes | Background services |
| ~/Library/LoginItems | ⚠️ Partial | Misses Sonoma+ System Settings items |
| /etc/crontab | ✅ Yes | Scheduled tasks |
| Browser Extensions | ✅ Yes | Safari, Chrome, Firefox |

**Keylogger detection:** Uses heuristic analysis (suspicious process names). Cannot definitively detect keyloggers without Full Disk Access. See [LIMITATIONS.md](LIMITATIONS.md).

### Developer Profiles

Pre-configured cleanup for:

- **Xcode** — DerivedData, Archives, iOS Device Support, Simulators
- **Docker** — Containers, images, system prune
- **Node.js** — npm cache, yarn cache
- **Homebrew** — Cache, cleanup
- **Python** — pip cache, __pycache__
- **Rust** — cargo cache, build artifacts
- **Go** — module cache
- **Custom** — Add your own shell commands

---

## Usage

### Menu Bar

Pulse lives in your menu bar for quick access:

- **Memory %** — Current memory pressure (color-coded)
- **Click** — Open popover with quick stats
- **Right-click** — Full menu with actions

### Dashboard

The main window has 9 tabs:

| Tab | Purpose |
|-----|---------|
| Health | Overview, health score, recommendations |
| Memory | Detailed memory stats and history |
| System | CPU, Disk, Network, Battery |
| Caches | Package manager cache sizes |
| Optimizer | Process list, cleanup, history |
| Developer | Dev tool profiles and actions |
| Security | Persistence scanner |
| History | Metric charts over time |
| Disk Explorer | Tree view of disk usage |

### Settings (⌘,)

| Section | Options |
|---------|---------|
| General | Refresh rate, menu bar mode, launch at login |
| Alerts | Memory thresholds (80%, 90%, 95%), cooldown |
| Display | Toggle CPU/Disk/Network/Battery sections |
| Guard | Auto-kill thresholds, whitelist |
| Cleanup | Xcode, Docker, cache locations |

---

## Permissions

Pulse requests minimal permissions:

| Permission | Why | Required? |
|------------|-----|-----------|
| **Full Disk Access** | Security scanner can read protected directories | Optional (feature degraded without) |
| **Accessibility** | Detect apps with keyboard monitoring | Optional (security scan limited) |
| **Apple Events** | Count browser tabs, manage apps | Optional (Safari tab count won't work) |
| **Notifications** | Memory threshold alerts | Optional (alerts won't show) |

### Check Permission Status

Go to **Security** tab → See permission indicators at top.

### Grant Permissions

1. Click "Grant" button next to each permission
2. System Settings opens automatically
3. Toggle Pulse in the list
4. Return to Pulse and click "Rescan"

---

## Troubleshooting

### Temperature shows 0°C

SMC-based temperature reading may not work on all Mac models, especially Apple Silicon (M1/M2/M3). This is a hardware limitation, not a bug.

**Workaround:** Use iStat Menus or Stats app for comprehensive sensor support.

### Security scan shows "Limited detection"

Pulse needs Full Disk Access to read certain system directories.

**Fix:** System Settings → Privacy & Security → Full Disk Access → Enable Pulse

### Login Items scan is incomplete

macOS Sonoma+ moved login items to System Settings, which Pulse cannot read.

**Workaround:** Check System Settings → General → Login Items manually.

### Docker cleanup fails

Requires Docker CLI at `/usr/local/bin/docker`.

**Fix:** Install Docker Desktop or ensure Docker CLI is in PATH.

### Tests crash when running HealthScore tests

Some tests require full app context (UNUserNotificationCenter).

**Workaround:** Run specific test suites:
```bash
swift test --filter SafetyFeaturesTests  # Works
swift test --filter AppSettingsTests     # Works
# Avoid tests that access MemoryMonitorManager.shared
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more.

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
│   ├── Models/
│   │   ├── MemoryTypes.swift     # Data models
│   │   ├── AppSettings.swift     # UserDefaults wrapper
│   │   ├── Brand.swift           # App branding
│   │   └── DeveloperProfile.swift # Dev tool definitions
│   ├── Services/
│   │   ├── SystemMemoryMonitor.swift
│   │   ├── ProcessMemoryMonitor.swift
│   │   ├── CPUMonitor.swift
│   │   ├── DiskMonitor.swift
│   │   ├── SystemHealthMonitor.swift
│   │   ├── SecurityScanner.swift
│   │   ├── MemoryOptimizer.swift
│   │   ├── ComprehensiveOptimizer.swift
│   │   ├── StorageAnalyzer.swift
│   │   ├── SmartSuggestions.swift
│   │   └── ... (12 more services)
│   ├── Views/
│   │   ├── DashboardView.swift
│   │   ├── HealthView.swift
│   │   ├── MemorySection.swift
│   │   ├── OptimizerView.swift
│   │   ├── SecurityView.swift
│   │   ├── DeveloperView.swift
│   │   └── ... (20 more views)
│   └── Utilities/
│       ├── DesignSystem.swift    # Colors, typography, spacing
│       └── DirectorySizeUtility.swift
├── Tests/
│   ├── SafetyFeaturesTests.swift
│   ├── AppSettingsTests.swift
│   ├── SecurityScannerTests.swift
│   └── DeveloperProfilesTests.swift
├── Pulse.entitlements
├── Package.swift
└── docs/
```

### Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

### Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Areas that need help:**
- [ ] Xcode project for proper entitlements/signing
- [ ] Notarization workflow
- [ ] Sparkle auto-updates
- [ ] Historical charts (Swift Charts integration)
- [ ] Disk treemap visualization
- [ ] More cleanup profiles
- [ ] Unit test coverage

---

## Security Considerations

### What Pulse Can Access

With **Full Disk Access**:
- All user files
- System directories (/Library, /System)
- Other apps' data

Without Full Disk Access:
- User-owned files only
- Limited security scanning
- Cannot read TCC database

### What Pulse Does With Access

- **Reads:** File sizes, directory contents, process info
- **Writes:** Deletes cache files (with user confirmation)
- **Sends:** Nothing (no telemetry, no analytics)

### Safety Guarantees

- ✅ Protected system paths cannot be deleted
- ✅ In-use files are skipped
- ✅ App bundles are protected
- ✅ User Documents/Desktop are protected
- ✅ Whitelist prevents killing critical processes

See [SECURITY.md](SECURITY.md) for security policy and threat model.

---

## Roadmap

### Phase 1: Foundation (Done)
- ✅ Core monitoring (memory, CPU, disk, network)
- ✅ Cache cleanup engine
- ✅ Security scanner
- ✅ Safety features (path validation, whitelists)
- ✅ Test coverage for safety features

### Phase 2: Polish (In Progress)
- [ ] Truthful documentation (capability matrix, limitations)
- [ ] Permission diagnostics screen
- [ ] Xcode project for entitlements
- [ ] Code signing + notarization
- [ ] User onboarding flow

### Phase 3: Features (Planned)
- [ ] Historical charts (Swift Charts)
- [ ] Disk treemap visualization
- [ ] Scheduled cleanup
- [ ] Cleanup history with undo
- [ ] More developer profiles

### Phase 4: Distribution (Future)
- [ ] Sparkle auto-updates
- [ ] App Store submission (if feasible)
- [ ] Website + landing page
- [ ] Demo videos

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

*Last updated: March 27, 2026*
*Version: 1.1 (pre-release)*
