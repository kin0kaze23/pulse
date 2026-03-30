# Pulse Architecture

> Technical architecture documentation for developers

---

## Overview

Pulse is a native macOS 14+ menu bar app built with SwiftUI. It follows a **service-oriented architecture** with a central coordinator pattern.

```
┌─────────────────────────────────────────────────────────────┐
│                      App.swift                              │
│  (Main entry, menu bar lifecycle, window management)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              MemoryMonitorManager (Coordinator)             │
│  (Central hub connecting all services, publishes state)     │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   System     │     │   Process    │     │     CPU      │
│   Memory     │     │   Memory     │     │   Monitor    │
│   Monitor    │     │   Monitor    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    Disk      │     │    System    │     │   Security   │
│   Monitor    │     │    Health    │     │   Scanner    │
│              │     │   Monitor    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Memory     │     │  Developer   │     │    Smart     │
│  Optimizer   │     │   Profiles   │     │ Suggestions  │
│              │     │    Engine    │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
```

---

## Design Patterns

### 1. ObservableObject + @Published

All services conform to `ObservableObject` and publish state changes:

```swift
class SystemMemoryMonitor: ObservableObject {
    @Published var currentMemory: SystemMemoryInfo?
    @Published var pressureLevel: MemoryPressureLevel = .normal
}
```

Views observe these changes via `@ObservedObject`:

```swift
struct MemorySection: View {
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared
    // ...
}
```

### 2. Singleton Services

All monitors are singletons to prevent resource duplication:

```swift
class CPUMonitor: ObservableObject {
    static let shared = CPUMonitor()
    private init() {}
}
```

### 3. Coordinator Pattern

`MemoryMonitorManager` coordinates all services:

```swift
class MemoryMonitorManager: ObservableObject {
    static let shared = MemoryMonitorManager()
    
    let systemMonitor = SystemMemoryMonitor.shared
    let processMonitor = ProcessMemoryMonitor.shared
    let cpuMonitor = CPUMonitor.shared
    // ...
    
    func start() {
        systemMonitor.startMonitoring(interval: settings.refreshInterval)
        // ... start all monitors
    }
}
```

### 4. Combine Bindings

Services use Combine for reactive programming:

```swift
settings.$refreshInterval
    .removeDuplicates()
    .sink { [weak self] interval in
        self?.systemMonitor.startMonitoring(interval: interval)
    }
    .store(in: &cancellables)
```

---

## Directory Structure

```
MemoryMonitor/Sources/
├── App.swift                    # Main entry point
│
├── Models/
│   ├── MemoryTypes.swift        # SystemMemoryInfo, ProcessMemoryInfo
│   ├── AppSettings.swift        # UserDefaults wrapper
│   ├── Brand.swift              # App branding constants
│   └── DeveloperProfile.swift   # Dev tool profile definitions
│
├── Services/
│   ├── SystemMemoryMonitor.swift    # mach VM APIs
│   ├── ProcessMemoryMonitor.swift   # proc_pidinfo
│   ├── CPUMonitor.swift             # host_processor_info
│   ├── DiskMonitor.swift            # FileManager volumes
│   ├── SystemHealthMonitor.swift    # Battery, thermal, network
│   ├── SecurityScanner.swift        # Persistence scanner
│   ├── MemoryOptimizer.swift        # Cleanup coordinator
│   ├── ComprehensiveOptimizer.swift # Cache cleanup engine
│   ├── StorageAnalyzer.swift        # Large file finder
│   ├── SmartSuggestions.swift       # Rule-based suggestions
│   ├── DeveloperProfilesEngine.swift # Dev tool detection
│   ├── AutoKillManager.swift        # Runaway process guard
│   ├── AlertManager.swift           # Notifications
│   ├── BrowserExtensionScanner.swift # Extension scanner
│   ├── CronJobScanner.swift         # Cron job detection
│   ├── CodeSignVerifier.swift       # Code signing check
│   ├── TemperatureMonitor.swift     # SMC temperature
│   ├── TimeMachineManager.swift     # Snapshot management
│   ├── PackageManagerCacheService.swift # Package manager caches
│   ├── DiskExplorerService.swift    # Tree view engine
│   └── HistoricalMetricsService.swift # Chart data storage
│
├── Views/
│   ├── DashboardView.swift      # Main window with tabs
│   ├── HealthView.swift         # Health score overview
│   ├── MemorySection.swift      # Memory details tab
│   ├── SystemView.swift         # CPU/Disk/Network/Battery
│   ├── OptimizerView.swift      # Process management
│   ├── DeveloperView.swift      # Dev tool profiles
│   ├── SecurityView.swift       # Security scanner
│   ├── HistoryChartsView.swift  # Metric history
│   ├── DiskExplorerView.swift   # Disk tree view
│   ├── SettingsView.swift       # Settings window
│   ├── MenuBarLiteView.swift    # Minimal menu bar
│   ├── SmartSuggestionsView.swift # Suggestions list
│   └── Components/              # Reusable components
│       ├── BatteryStatusView.swift
│       ├── TemperatureGaugeView.swift
│       ├── MemoryGaugeView.swift
│       └── ...
│
└── Utilities/
    ├── DesignSystem.swift       # Colors, typography, spacing
    ├── NavigationManager.swift  # Tab navigation
    ├── DirectorySizeUtility.swift # du -sk wrapper
    └── OptimizationTypes.swift  # Shared types
```

---

## Data Flow

### 1. Monitoring Loop

```
Timer (every 2s)
    │
    ▼
SystemMemoryMonitor.updateMemoryInfo()
    │
    ├─► Read mach VM stats
    ├─► Calculate percentages
    └─► Publish @Published var currentMemory
            │
            ▼
    MemoryMonitorManager (observes)
            │
            ▼
    DashboardView (observes)
            │
            ▼
    MemorySection (renders)
```

### 2. Cleanup Flow

```
User clicks "Optimize"
    │
    ▼
MemoryOptimizer.freeRAM()
    │
    ▼
ComprehensiveOptimizer.scanForCleanup()
    │
    ├─► Scan developer caches
    ├─► Scan browser caches
    ├─► Scan system caches
    └─► Build CleanupPlan
            │
            ▼
    Show confirmation dialog
            │
            ▼
    User confirms
            │
            ▼
    ComprehensiveOptimizer.executeCleanup()
            │
            ├─► Validate paths
            ├─► Check safety
            ├─► Delete files
            └─► Publish OptimizeResult
                    │
                    ▼
            Update UI with results
```

### 3. Security Scan Flow

```
User opens Security tab
    │
    ▼
SecurityScanner.scan()
    │
    ├─► Scan LaunchAgents
    ├─► Scan LaunchDaemons
    ├─► Scan LoginItems
    └─► Check keyloggers (heuristic)
            │
            ▼
    Publish persistenceItems array
            │
            ▼
    SecurityView renders list
            │
            ▼
    User clicks "Disable"
            │
            ▼
    SecurityScanner.disableItem()
            │
            └─► launchctl unload
```

---

## Key Services

### SystemMemoryMonitor

**Purpose:** Read system memory stats via mach APIs

**Key methods:**
- `startMonitoring(interval:)` — Start timer
- `updateMemoryInfo()` — Read VM stats
- `readSystemMemory()` — mach host_statistics64

**Data sources:**
- `host_statistics64(HOST_VM_INFO64)` — VM stats
- `sysctlbyname("hw.memsize")` — Physical memory
- `sysctlbyname("vm.swapusage")` — Swap info

---

### ProcessMemoryMonitor

**Purpose:** Track per-process memory usage

**Key methods:**
- `refresh(topN:)` — Update process list
- `getAllProcesses()` — Enumerate all PIDs
- `getProcessInfo(pid:)` — Read process memory

**Data sources:**
- `proc_listallpids()` — Get all PIDs
- `proc_pidinfo(PROC_PIDTASKINFO)` — Per-process memory
- `proc_name()` — Process name
- `proc_pidpath()` — Process path

---

### CPUMonitor

**Purpose:** Monitor CPU usage

**Key methods:**
- `update()` — Read CPU stats
- `updateProcessCPU()` — Per-process CPU

**Data sources:**
- `host_processor_info()` — CPU stats
- `proc_pidinfo()` — Process CPU time

---

### SecurityScanner

**Purpose:** Detect persistence mechanisms

**Key methods:**
- `scan()` — Full security scan
- `scanLaunchAgents()` — Parse plist files
- `checkForKeyloggers()` — Heuristic detection

**Data sources:**
- `~/Library/LaunchAgents/*.plist`
- `/Library/LaunchDaemons/*.plist`
- `NSWorkspace.runningApplications`

---

### ComprehensiveOptimizer

**Purpose:** Cache cleanup engine

**Key methods:**
- `scanForCleanup()` — Dry-run scan
- `executeCleanup()` — Perform cleanup
- `cleanPath(_:)` — Delete with safety checks

**Cleanup targets:**
- Xcode DerivedData
- Browser caches
- npm/yarn/pip caches
- System caches
- Time Machine snapshots

---

## Threading Model

### Main Thread
- UI updates
- @Published property changes
- Timer scheduling

### Background Queues

```swift
// Heavy operations run on background queues
DispatchQueue.global(qos: .userInitiated).async {
    // Scan filesystem
    // Run shell commands
    // Calculate sizes
}

// Battery/network on utility queue (less frequent)
DispatchQueue.global(qos: .utility).async {
    // Read battery status
    // Check network
}
```

### Thread Safety

- All `@Published` updates dispatched to main
- Icon cache uses simple dictionary (not thread-safe, but only accessed from main)
- File watchers use dedicated serial queue

---

## Error Handling

### Strategy

- **Monitoring:** Silent failures (continue on error)
- **Cleanup:** Log error, return 0 freed, continue
- **Security:** Mark as "scan failed", show partial results

### Example

```swift
private func cleanPath(_ path: String) -> Double {
    guard FileManager.default.fileExists(atPath: path) else {
        print("[Optimizer] Path does not exist: \(path)")
        return 0
    }
    
    do {
        try FileManager.default.removeItem(atPath: path)
        return size
    } catch {
        print("[Optimizer] Failed to clean \(path): \(error)")
        return 0
    }
}
```

---

## Performance Considerations

### Optimizations

1. **Icon caching** — 30s TTL, prune inactive PIDs
2. **Battery polling** — Runs on background queue, 5s interval
3. **Cycle count** — 30s interval (expensive ioreg call)
4. **Disk monitoring** — 30s interval (rarely changes)
5. **History trimming** — Keep last 300 entries only

### Known Bottlenecks

1. **`du -sk` for directory sizes** — Can be slow for large folders
2. **node_modules scanning** — Limited to depth 5, 10k items
3. **Security plist parsing** — Skips codesign verification (too slow)

---

## Testing Strategy

### Unit Tests

- `AppSettingsTests` — Settings persistence
- `DeveloperProfilesTests` — Profile model validation
- `SecurityScannerTests` — Risk level enums
- `SafetyFeaturesTests` — Path safety validation

### Integration Tests (TODO)

- Permission state handling
- Delete preview accuracy
- Monitor fallback behavior

### Manual Testing

- Menu bar behavior
- Window management
- Settings persistence
- Notification delivery

---

## Dependencies

### System Frameworks

- `IOKit` — SMC temperature reading
- `SystemConfiguration` — Network reachability
- `UserNotifications` — Alert notifications
- `ServiceManagement` — Launch at login

### No Third-Party Dependencies

Pulse uses zero external packages. All functionality is implemented with Apple frameworks.

---

## Future Architecture Changes

### Planned

1. **HistoricalMetricsService integration** — Store metrics to disk for trend analysis
2. **Swift Charts** — Replace sparklines with proper charts
3. **Endpoint Security** — Real-time threat detection (requires system extension)
4. **Plugin architecture** — Allow custom cleanup scripts

### Under Consideration

1. **CoreML integration** — Anomaly detection for resource usage
2. **CloudKit sync** — Sync settings across Macs
3. **WidgetKit** — macOS widget for Notification Center

---

*Last updated: March 27, 2026*
*Version: 1.1 (pre-release)*
