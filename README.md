# Pulse

> Keep your Mac in flow

A native macOS menu bar app for real-time system health monitoring, built with SwiftUI.

## Features

### Core Monitoring
- **Menu Bar Integration** — Always-visible memory % with color-coded pressure indicators
- **Memory Monitoring** — Live gauge, breakdown bar, swap tracking, history chart
- **CPU Monitoring** — Per-core gauges, usage history, top CPU processes
- **Disk Monitoring** — Storage usage, volume list, free space alerts
- **Network Monitoring** — Download/upload speed with live chart
- **Battery & Thermal** — Battery health, cycle count, charging status, thermal state

### Intelligence
- **Health Score** — A-F grading system with smart recommendations
- **Smart Optimization** — One-click memory cleanup with safe defaults
- **Runaway Process Guard** — Auto-kill processes exceeding configurable thresholds
- **Configurable Alerts** — Memory threshold notifications with cooldown

### Security
- **Persistence Scanner** — Detect launch agents, daemons, and login items
- **Keylogger Detection** — Monitor for suspicious accessibility permissions
- **Real-Time Monitoring** — Continuous threat detection

### Developer Tools
- **Profile-Based Cleanup** — Tailored cleanup for Xcode, Docker, Node.js, Homebrew, and more
- **Custom Rules** — Add your own cleanup commands
- **Disk Usage Breakdown** — See exactly where dev tools store their caches

## Requirements

- macOS 14.0+
- Swift 5.9+

## Build & Run

```bash
# Clone the repository
git clone https://github.com/jonathannugroho/pulse.git
cd pulse

# Build release
swift build -c release

# Create .app bundle
mkdir -p build/Pulse.app/Contents/MacOS
cp .build/release/MemoryMonitor build/Pulse.app/Contents/MacOS/

# Sign and launch
codesign --force --deep --sign - build/Pulse.app
open build/Pulse.app
```

## Development

```bash
# Build debug
swift build

# Run tests
swift test

# Build release
swift build -c release
```

## Project Structure

```
MemoryMonitor/
├── Package.swift
├── MemoryMonitor/Sources/
│   ├── App.swift                    # Main app entry + menu bar
│   ├── Models/
│   │   ├── MemoryTypes.swift        # Data models
│   │   ├── AppSettings.swift        # UserDefaults preferences
│   │   ├── Brand.swift              # App branding
│   │   └── DeveloperProfile.swift   # Dev tool profiles
│   ├── Services/
│   │   ├── SystemMemoryMonitor.swift    # Kernel memory + VM stats
│   │   ├── ProcessMemoryMonitor.swift   # Per-process memory
│   │   ├── CPUMonitor.swift             # CPU usage
│   │   ├── DiskMonitor.swift            # Disk usage
│   │   ├── SystemHealthMonitor.swift    # Battery/thermal/network
│   │   ├── SecurityScanner.swift        # Persistence/keylogger detection
│   │   ├── AlertManager.swift           # Notifications
│   │   ├── MemoryOptimizer.swift        # Cleanup engine
│   │   ├── DeveloperProfilesEngine.swift # Dev tool management
│   │   └── MemoryMonitorManager.swift   # Central coordinator
│   ├── Utilities/
│   │   ├── DesignSystem.swift       # Colors, typography, spacing
│   │   └── NavigationManager.swift  # Tab navigation
│   └── Views/
│       ├── DashboardView.swift      # Main window with 6 tabs
│       ├── HealthView.swift         # Overview + vitality orb
│       ├── MemorySection.swift      # Memory details
│       ├── SystemView.swift         # CPU + Disk + Network + Battery
│       ├── OptimizerView.swift      # Process management + cleanup
│       ├── DeveloperView.swift      # Dev tool profiles
│       ├── SecurityView.swift       # Security scanner
│       └── Components/
│           ├── BatteryStatusView.swift
│           └── SkeletonView.swift
└── Tests/
    ├── HealthScoreTests.swift
    ├── SecurityScannerTests.swift
    ├── DeveloperProfilesTests.swift
    └── AppSettingsTests.swift
```

## Tabs

| Tab | Icon | Description |
|-----|------|-------------|
| Health | `heart.text.square.fill` | Overview, vitality orb, recommendations |
| Memory | `memorychip` | Detailed memory stats, history chart |
| System | `cpu` | CPU, Disk, Network, Battery in one place |
| Optimizer | `sparkles` | Process list, auto-kill guard, cleanup stats |
| Developer | `terminal.fill` | Dev tool profiles, custom cleanup rules |
| Security | `shield.checkered` | Persistence scanner, keylogger detection |

## Settings

Configure via ⌘, (Settings window):
- **General**: Refresh rate, menu bar display, launch at login
- **Alerts**: Memory thresholds (80%, 90%, 95%), notification cooldown
- **Display**: Toggle CPU/Disk/Network/Battery sections
- **Guard**: Auto-kill thresholds, whitelist management
- **Cleanup**: Xcode derived data, device support, cache locations

## License

MIT License - see LICENSE file for details.

---

Built with ❤️ for macOS developers who want their machines running at peak performance.