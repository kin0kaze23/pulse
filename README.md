# MemoryMonitor

A native macOS app for real-time system health monitoring built with SwiftUI.

## Features

- **Menu Bar Integration** — Always-visible memory % with color-coded alerts
- **Memory Monitoring** — Live gauge, breakdown bar, history chart
- **CPU Monitoring** — Per-core gauges, history, top CPU processes
- **Disk Monitoring** — Storage usage, volume list
- **Network Monitoring** — Download/upload speed with live chart
- **Battery & Thermal** — Battery health, cycle count, thermal state
- **Process Management** — Top processes table with one-click kill
- **Runaway Process Guard** — Auto-kill processes exceeding configurable thresholds
- **Configurable Alerts** — Memory threshold notifications with cooldown
- **Health Score** — A-F grading system with smart recommendations

## Requirements

- macOS 14.0+
- Swift 5.9+

## Build & Run

```bash
# Build release
swift build -c release

# Create .app bundle
mkdir -p build/MemoryMonitor.app/Contents/MacOS
cp .build/release/MemoryMonitor build/MemoryMonitor.app/Contents/MacOS/
# (Info.plist included in build/)

# Sign and launch
codesign --force --deep --sign - build/MemoryMonitor.app
open build/MemoryMonitor.app
```

## Project Structure

```
MemoryMonitor/
├── Package.swift
├── MemoryMonitor/Sources/
│   ├── App.swift              # Main app entry + menu bar
│   ├── Models/
│   │   ├── MemoryTypes.swift  # Data models
│   │   └── AppSettings.swift  # UserDefaults preferences
│   ├── Services/
│   │   ├── SystemMemoryMonitor.swift   # Mach VM stats
│   │   ├── ProcessMemoryMonitor.swift  # Per-process memory
│   │   ├── CPUMonitor.swift            # CPU usage
│   │   ├── DiskMonitor.swift           # Disk usage
│   │   ├── SystemHealthMonitor.swift   # Battery/thermal/network
│   │   ├── AlertManager.swift          # Notifications
│   │   ├── AutoKillManager.swift       # Runaway process guard
│   │   └── MemoryMonitorManager.swift  # Central coordinator
│   └── Views/
│       ├── DashboardView.swift         # Main window
│       ├── MemoryGaugeView.swift       # Circular gauge
│       ├── MemoryBreakdownView.swift   # Memory categories
│       ├── MemoryHistoryView.swift     # History chart
│       ├── CPUView.swift               # CPU monitoring
│       ├── DiskView.swift              # Storage view
│       ├── NetworkView.swift           # Network stats
│       ├── BatteryThermalView.swift    # Battery/thermal
│       ├── ProcessListView.swift       # Process table
│       ├── HealthScoreView.swift       # Health score card
│       ├── AutoKillView.swift          # Process guard
│       └── SettingsView.swift          # Preferences
```

## Settings

Configure via ⌘, (Settings window):
- **General**: Refresh rate, menu bar display, launch at login
- **Alerts**: Memory thresholds (75%, 85%, 95%), notification cooldown
- **Display**: Toggle CPU/Disk/Network/Battery sections
- **Guard**: Auto-kill thresholds, whitelist management
