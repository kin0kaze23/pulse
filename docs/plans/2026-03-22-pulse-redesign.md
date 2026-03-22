# Pulse — macOS System Health Monitor
## Design & Implementation Plan
**Date:** 2026-03-22
**Strategy:** Approach C — Parallel Phased Refactor (Track 1: Engine, Track 2: UI)
**Executor:** GLM-5 / AI agent
**Distribution:** Open source, GitHub, direct .dmg (no App Store sandbox)

---

## 0. Project Overview

Pulse is a native macOS 14+ menu bar app that monitors system health (memory, CPU, disk, network, battery, thermal), detects security threats (persistence items, keyloggers), and provides intelligent optimization actions (cache cleanup, process management, developer tool cleanup).

**Current state:** Functional prototype with working engine and basic UI. Critical bugs, deprecated APIs, inconsistent branding, and architectural debt need to be resolved before public launch.

**Goal:** Ship a production-quality, premium-feeling macOS app that users trust and want to keep running 24/7.

---

## 1. Brand Identity — "Pulse"

### 1.1 Name & Identity
- **App name:** Pulse
- **Tagline:** Keep your Mac in flow
- **Bundle identifier:** `com.jonathannugroho.pulse`
- **Primary CTA:** "Optimize Now"

### 1.2 Files to Update for Branding
| File | Change |
|---|---|
| `MemoryMonitor/Sources/Models/Brand.swift` | Already correct — `name = "Pulse"`, `shortTagline = "Keep your Mac in flow"`. No changes needed. |
| `MemoryMonitor/Sources/App.swift` | `WindowGroup("Memory Monitor")` → `WindowGroup("Pulse")` |
| `MemoryMonitor/Sources/App.swift` | `Window("Settings", id: "settings")` stays as-is |
| `Package.swift` | Keep target name `MemoryMonitor` (internal binary name). Add `displayName` if SPM supports it — otherwise leave. |
| `README.md` | Rebrand all "MemoryMonitor" references to "Pulse". Update build instructions. |
| `.git/config` remote description | Optional — update repo description on GitHub |

### 1.3 Unified Color System
**Problem:** Three competing color systems exist — `Brand.swift` colors, `DesignSystem.Colors`, and raw `Color.blue/.orange/.red` scattered in views.

**Resolution:** All semantic colors live in `DesignSystem.swift`. `Brand.swift` keeps only name/tagline/CTA strings. All views reference `DesignSystem.Colors.*` exclusively.

Add the following to `DesignSystem.Colors` in `DesignSystem.swift`:
```swift
// Semantic metric colors
static let memory    = Color.blue
static let cpu       = Color.purple
static let disk      = Color.orange
static let network   = Color.cyan
static let battery   = Color.green
static let thermal   = Color.red

// Score colors
static func score(_ value: Int) -> Color {
    switch value {
    case 90...100: return .green
    case 80..<90:  return .blue
    case 70..<80:  return .yellow
    case 50..<70:  return .orange
    default:       return .red
    }
}

// Battery helpers
static func battery(percentage: Double, isCharging: Bool) -> Color {
    if isCharging { return .green }
    return percentage > 20 ? .green : .red
}
```

Remove `neutralTint`, `accentTint`, `successTint`, `warningTint`, `dangerTint` from `Brand.swift` — they duplicate `DesignSystem.Colors`.

**All views:** Replace `Color.blue`, `Color.orange`, `Color.red`, `Color.green`, `Color.purple`, `Color.cyan` literals with `DesignSystem.Colors.memory`, `.cpu`, `.disk`, etc. where they represent metrics.

### 1.4 Duplicate Computed Properties to Eliminate
The following are copy-pasted in multiple views. Extract them to shared location.

| Property | Currently in | Move to |
|---|---|---|
| `scoreColor` | `MenuBarPopoverContent`, `DashboardView`, `HealthView` | `DesignSystem.Colors.score(Int)` static func |
| `batteryIcon` | `MenuBarPopoverContent`, `DashboardView` | New `BatteryStatusView` component |
| `batteryColor` | `MenuBarPopoverContent`, `DashboardView` | New `BatteryStatusView` component |

Create `MemoryMonitor/Sources/Views/Components/BatteryStatusView.swift`:
```swift
struct BatteryStatusView: View {
    let percentage: Double
    let isCharging: Bool
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: batteryIcon)
                .foregroundColor(DesignSystem.Colors.battery(percentage: percentage, isCharging: isCharging))
            Text(String(format: "%.0f%%", percentage))
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
        }
    }
    private var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        if percentage > 75 { return "battery.100" }
        if percentage > 50 { return "battery.75" }
        if percentage > 25 { return "battery.50" }
        return "battery.25"
    }
}
```

---

## 2. Navigation Redesign

### 2.1 Problem
The "More" tab is a junk drawer containing CPU, Disk, Network, Battery, Guard, and Process List — six unrelated concerns crammed into one tab. This violates progressive disclosure and makes the app feel unfinished.

### 2.2 New Tab Structure
Replace the 6-tab layout with a semantically clean 6-tab layout:

| Tab | Icon | Content |
|---|---|---|
| **Health** | `heart.text.square.fill` | Overview: Vitality Orb, bento grid, primary action card, smart suggestions, top 3 processes |
| **Memory** | `memorychip` | Detailed gauge, breakdown bar, history chart, all memory stats |
| **System** | `cpu` | CPU gauges + history, Disk usage + volumes, Network speeds + history, Battery + Thermal |
| **Optimizer** | `sparkles` | Process list (kill), Process Guard (auto-kill), Cleanup engine (cache + storage), Cleanup history |
| **Developer** | `terminal.fill` | Dev tool profiles (Xcode, Docker, Node, OpenCode, etc.), custom rules |
| **Security** | `shield.checkered` | Persistence scanner, keylogger check, real-time monitoring, threat events |

Settings moves to a **gear button in the top bar** (already has a button area) — not a sidebar tab. This is more macOS-native (like System Settings, Xcode preferences). The Settings window already exists as a separate `Window` scene — just remove it from the sidebar and keep the keyboard shortcut `Cmd+,`.

### 2.3 Changes to DashboardView.swift
```swift
enum Tab: String, CaseIterable {
    case health    = "Health"
    case memory    = "Memory"
    case system    = "System"
    case optimizer = "Optimizer"
    case developer = "Developer"
    case security  = "Security"

    var icon: String {
        switch self {
        case .health:    return "heart.text.square.fill"
        case .memory:    return "memorychip"
        case .system:    return "cpu"
        case .optimizer: return "sparkles"
        case .developer: return "terminal.fill"
        case .security:  return "shield.checkered"
        }
    }
}
```

Add a settings button to the top bar (right side, next to refresh):
```swift
Button {
    openSettingsWindow()
} label: {
    Image(systemName: "gear")
        .font(.system(size: 11, weight: .medium))
}
.buttonStyle(.plain)
.padding(6)
.background(Circle().fill(Color.primary.opacity(0.06)))
.foregroundColor(.secondary)
.hoverEffect()
.keyboardShortcut(",", modifiers: .command)
```

### 2.4 New SystemView.swift
Create `MemoryMonitor/Sources/Views/SystemView.swift`. Move content from `MoreView` (currently in `DashboardView.swift`) into a proper `SystemView`:
```swift
struct SystemView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader(icon: "cpu", title: "System", subtitle: "CPU, Disk, Network, Battery")
            CPUView()
            Divider()
            DiskView()
            Divider()
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                NetworkView()
                BatteryThermalView()
            }
        }
    }
}
```

### 2.5 New OptimizerView.swift
Create `MemoryMonitor/Sources/Views/OptimizerView.swift`:
```swift
struct OptimizerView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader(icon: "sparkles", title: "Optimizer", subtitle: "Process management and system cleanup")
            ProcessListView()
            Divider()
            AutoKillView()
            Divider()
            CleanupStatsView()
        }
    }
}
```

### 2.6 Remove MoreView
Delete the `MoreView` struct from `DashboardView.swift`. Its content now lives in `SystemView` and `OptimizerView`.

---

## 3. Track 1 — Engine Fixes

All changes in this track are in `MemoryMonitor/Sources/Services/` and `MemoryMonitor/Sources/Models/`. No view files touched.

### 3.1 Fix: Deprecated NSUserNotification API
**Severity:** Critical — `NSUserNotification` is removed in macOS 14+ SDK.
**Files:** `AlertManager.swift`, `SecurityScanner.swift`

**Pattern to replace everywhere:**
```swift
// REMOVE THIS:
let notification = NSUserNotification()
notification.title = "..."
notification.informativeText = "..."
NSUserNotificationCenter.default.deliver(notification)

// REPLACE WITH:
import UserNotifications

private func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
}

private func sendNotification(title: String, body: String, identifier: String = UUID().uuidString) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
}
```

In `AlertManager.swift`: call `requestNotificationPermission()` in `init()`. Replace all `NSUserNotification` usage with `sendNotification(title:body:identifier:)`.

In `SecurityScanner.swift`: replace `showSecurityNotification(title:body:)` body with the same `sendNotification` call.

In `App.swift` `AppDelegate.applicationDidFinishLaunching`: add `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }`.

### 3.2 Fix: Real Kernel Memory Pressure Events
**Severity:** High — current `calculatePressure(usedPercentage:)` uses simple `> 85%` heuristic which differs from macOS's actual memory pressure state.
**File:** `SystemMemoryMonitor.swift`

Add kernel pressure monitoring alongside the existing percentage-based calculation:
```swift
// Add to SystemMemoryMonitor properties:
private var pressureSource: DispatchSourceMemoryPressure?

// Add to startMonitoring():
private func startKernelPressureMonitoring() {
    pressureSource?.cancel()
    pressureSource = DispatchSource.makeMemoryPressureSource(
        eventMask: [.normal, .warning, .critical],
        queue: .main
    )
    pressureSource?.setEventHandler { [weak self] in
        guard let self, let source = self.pressureSource else { return }
        let event = source.data
        let kernelLevel: MemoryPressureLevel
        switch event {
        case .critical: kernelLevel = .critical
        case .warning:  kernelLevel = .warning
        default:        kernelLevel = .normal
        }
        // Kernel signal takes priority; percentage is secondary
        self.pressureLevel = kernelLevel
    }
    pressureSource?.resume()
}

// Update calculatePressure to be a fallback only:
// Called when kernel event is not available
private func calculatePressureFallback(usedPercentage: Double) -> MemoryPressureLevel {
    if usedPercentage >= 95 { return .critical }
    if usedPercentage >= 85 { return .warning }
    return .normal
}
```

Call `startKernelPressureMonitoring()` inside `startMonitoring(interval:)`. In `stopMonitoring()`, add `pressureSource?.cancel(); pressureSource = nil`.

In `updateMemoryInfo()`, only update `pressureLevel` from percentage if the kernel source hasn't fired yet (i.e., `lastKernelPressureEvent == nil`).

### 3.3 Fix: Polling Anti-Patterns in MemoryOptimizer
**Severity:** High — `while isWorking { Thread.sleep(0.1) }` blocks a background thread; the 100ms recursive `asyncAfter` loop can accumulate.
**File:** `MemoryOptimizer.swift`

Replace all three polling loops (`executeCleanup`, `quickOptimize`, `quickCleanCaches`) with a Combine-based completion pattern:

```swift
// Add to MemoryOptimizer:
private var completionCancellable: AnyCancellable?

private func waitForComprehensiveCompletion(then completion: @escaping () -> Void) {
    completionCancellable?.cancel()
    completionCancellable = comprehensive.$isWorking
        .filter { !$0 }  // wait for isWorking to become false
        .first()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            completion()
            self?.completionCancellable = nil
        }
}
```

Replace each `while self.comprehensive.isWorking { Thread.sleep(0.1) }` block in `executeCleanup()`, `quickOptimize()`, and `quickCleanCaches()` with:
```swift
waitForComprehensiveCompletion {
    // handle result — same code as the DispatchQueue.main.async block
}
```

Also replace the `checkCompletion()` recursive `asyncAfter` loop in `freeRAM()` with:
```swift
waitForComprehensiveCompletion { [weak self] in
    guard let self else { return }
    self.isWorking = false
    if self.comprehensive.needsConfirmation, let plan = self.comprehensive.currentPlan {
        self.pendingCleanupPlan = plan
        self.showCleanupConfirmation = true
    } else if let plan = self.comprehensive.currentPlan, plan.items.count > 0 {
        self.executeCleanup()
    } else {
        self.quickOptimize()
    }
}
```

### 3.4 Fix: Launch at Login
**Severity:** High — setting exists in UI but has no effect.
**File:** `AppSettings.swift`

```swift
import ServiceManagement

// In AppSettings, replace the launchAtLogin didSet:
@Published var launchAtLogin: Bool {
    didSet {
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        applyLaunchAtLogin(launchAtLogin)
    }
}

private func applyLaunchAtLogin(_ enable: Bool) {
    do {
        if enable {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        print("[AppSettings] Launch at login failed: \(error)")
    }
}

// In init(), sync the stored value with actual SMAppService status:
// (call after all properties initialized)
private func syncLaunchAtLoginStatus() {
    let actualStatus = SMAppService.mainApp.status == .enabled
    if launchAtLogin != actualStatus {
        launchAtLogin = actualStatus
    }
}
```

Call `syncLaunchAtLoginStatus()` at the end of `AppSettings.init()`.

### 3.5 Fix: SecurityScanner — Replace TCC.db SQLite Access
**Severity:** Critical — direct TCC.db access fails silently without Full Disk Access. Users get false "no risk" results.
**File:** `SecurityScanner.swift`

Replace `checkForKeyloggers()` entirely:
```swift
private func checkForKeyloggers() -> KeyloggerRisk {
    // Check if THIS app has Accessibility permission (AXIsProcessTrusted)
    // Then check running apps for suspicious accessibility usage

    var suspiciousApps = 0
    var totalAppsWithAccessibility = 0

    // Use NSWorkspace to get running apps, check their accessibility trust status
    let runningApps = NSWorkspace.shared.runningApplications

    for app in runningApps {
        guard let bundleID = app.bundleIdentifier else { continue }

        // Skip Apple apps
        if bundleID.hasPrefix("com.apple.") { continue }

        // Skip known safe apps
        let isSafe = knownSafeBundleIDs.contains { bundleID.hasPrefix($0) }
        if isSafe { continue }

        // Check if the app has suspicious keywords in its bundle ID or name
        let appName = app.localizedName?.lowercased() ?? ""
        let bundleLower = bundleID.lowercased()

        let hasSuspiciousKeyword = suspiciousKeywords.contains {
            bundleLower.contains($0) || appName.contains($0)
        }

        if hasSuspiciousKeyword {
            suspiciousApps += 1
        }

        // Count non-Apple, non-safe apps as candidates
        totalAppsWithAccessibility += 1
    }

    // Additionally: check if Full Disk Access is available to do deeper scan
    let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
    if FileManager.default.isReadableFile(atPath: tccPath) {
        return checkKeyloggersViaTCC(tccPath: tccPath,
                                     suspiciousSoFar: suspiciousApps)
    }

    // Fallback: keyword-based only
    if suspiciousApps > 0 { return .high }
    return .none
}

private func checkKeyloggersViaTCC(tccPath: String, suspiciousSoFar: Int) -> KeyloggerRisk {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    task.arguments = [tccPath,
        "SELECT client FROM access WHERE service='kTCCServiceAccessibility' AND allowed=1;"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()

    do {
        try task.run()
        let deadline = Date().addingTimeInterval(3)
        while task.isRunning && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        if task.isRunning { task.terminate(); return suspiciousSoFar > 0 ? .high : .none }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return .none }

        let apps = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        var suspicious = suspiciousSoFar
        var total = 0

        for app in apps {
            let lower = app.lowercased()
            if lower.hasPrefix("com.apple.") { continue }
            // FIX: use contains() predicate instead of broken nested continue
            let isSafe = knownSafeBundleIDs.contains { lower.contains($0.lowercased()) }
            if isSafe { continue }
            total += 1
            let hasSuspiciousKeyword = suspiciousKeywords.contains { lower.contains($0) }
            if hasSuspiciousKeyword { suspicious += 1 }
        }

        if suspicious > 0 { return .high }
        if total > 10 { return .medium }
        if total > 0 { return .low }
        return .none
    } catch {
        return suspiciousSoFar > 0 ? .high : .none
    }
}
```

Also add a `@Published var hasTCCAccess: Bool = false` property and check it in `scan()` to surface a UI hint ("Grant Full Disk Access for deeper scans").

### 3.6 Fix: SecurityScanner Keylogger Logic Bug
Already fixed in 3.5 above (the `continue` in inner `for safeID` loop is replaced with a `contains()` predicate that correctly skips the outer loop iteration).

### 3.7 Fix: Unify Swap Reading
**Severity:** Medium — `SystemMemoryMonitor` and `DeveloperMonitor` both independently read `vm.swapusage` via sysctl on every poll cycle.
**Files:** `DeveloperMonitor.swift`

In `DeveloperMonitor.readSwap()`, replace the sysctl call with:
```swift
private func readSwap() -> (used: Double, total: Double) {
    // Read from SystemMemoryMonitor instead of duplicating sysctl call
    let memory = SystemMemoryMonitor.shared.currentMemory
    return (memory?.swapUsedGB ?? 0, memory?.swapUsedGB ?? 0 + (memory?.freeGB ?? 0))
}
```

If `SystemMemoryMonitor.currentMemory` is nil on first call (race condition on startup), fall back to the sysctl call as before. Remove the sysctl import from DeveloperMonitor if it's no longer needed elsewhere.

### 3.8 Fix: openWindow() Fragile String Matching
**Severity:** Medium — title-based window lookup breaks if titles change.
**File:** `App.swift`

Replace the `openWindow(_:)` helper in `MenuBarPopoverContent` with SwiftUI's `@Environment(\.openWindow)` action:

```swift
struct MenuBarPopoverContent: View {
    @ObservedObject var manager: MemoryMonitorManager
    @Environment(\.openWindow) private var openWindow

    // In actionsSection:
    Button {
        NSApp.activate()
        openWindow(id: "main")   // matches WindowGroup id
    } label: { ... }

    Button {
        openWindow(id: "settings")
    } label: { ... }
}
```

In `App.swift`, give the main `WindowGroup` an explicit id:
```swift
WindowGroup("Pulse", id: "main") { ... }
```

Remove the `private func openWindow(_ identifier: String)` helper entirely from `MenuBarPopoverContent`.

### 3.9 Fix: Double showMainWindow() on Launch
**Severity:** Low — causes the window to be centered twice (flicker) on launch.
**File:** `App.swift`

In `AppDelegate`, remove the `showMainWindow()` call from `applicationDidBecomeActive`. Keep it only in `applicationDidFinishLaunching`. `applicationDidBecomeActive` fires on every app activation (e.g., switching back from another app) and should not force-reposition the window.

```swift
func applicationDidBecomeActive(_ notification: Notification) {
    // REMOVE: showMainWindow()
    // Only bring to front, do not reposition
    NSApp.activate(ignoringOtherApps: true)
}
```

### 3.10 Fix: HapticFeedback Missing Implementation
**Severity:** High — `HapticFeedback.medium()` and `HapticFeedback.light()` are referenced in multiple views but the type does not exist, causing a build error.
**Create:** `MemoryMonitor/Sources/Utilities/HapticFeedback.swift`

```swift
import AppKit

enum HapticFeedback {
    static func light() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }

    static func medium() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .default
        )
    }

    static func heavy() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )
    }
}
```

### 3.11 Fix: Remove Nested ScrollView in HealthView
**Severity:** Medium — `HealthView` has its own `ScrollView` but `DashboardView`'s `contentSection` is already inside a `ScrollView`. Nested scroll views cause scroll conflicts.
**File:** `HealthView.swift`

Remove the outer `ScrollView { ... }` wrapper from `HealthView.body`. The content `VStack` should be the direct body:
```swift
var body: some View {
    VStack(spacing: DesignSystem.Spacing.lg) {
        bentoGrid.staggeredEntrance(delay: 0.1)
        // ... rest of content
    }
    .padding(DesignSystem.Spacing.lg)
    .animation(...)
    .onAppear { ... }
}
```

Apply the same fix to any other tab content views that wrap themselves in a `ScrollView` (check `SecurityView`, `DeveloperView`, `MemorySection`). The single `ScrollView` in `DashboardView.contentSection` is the canonical scroll container.

### 3.12 Fix: App Activation Policy
**Severity:** Medium — `NSApp.setActivationPolicy(.regular)` makes Pulse appear in the Dock, which is wrong for a menu bar utility.
**File:** `App.swift`

In `AppDelegate.applicationDidFinishLaunching`:
```swift
// REMOVE:
NSApp.setActivationPolicy(.regular)
NSApp.activate()

// REPLACE WITH:
NSApp.setActivationPolicy(.accessory)  // Menu bar only — no Dock icon
// Window is opened by the MenuBarExtra click or openWindow environment action
```

If user needs to open the dashboard, they click the menu bar icon. This is standard macOS menu bar app behavior (iStat Menus, CleanMyMac X all use `.accessory`).

---

## 4. Developer Profiles System (Track 1, New Feature)

### 4.1 Data Model
Create `MemoryMonitor/Sources/Models/DeveloperProfile.swift`:

```swift
import SwiftUI

struct DeveloperProfile: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let category: Category
    let detectMethod: DetectMethod
    let memoryProcessPatterns: [String]
    let diskScans: [DiskScan]
    let cleanupActions: [CleanupAction]
    let description: String

    enum Category: String, CaseIterable {
        case appleTools      = "Apple Tools"
        case containers      = "Containers"
        case languages       = "Languages"
        case editors         = "Editors"
        case packageManagers = "Package Managers"
        case versionControl  = "Version Control"
        case custom          = "Custom"
    }

    enum DetectMethod {
        case processName(String)      // Check via ps/pgrep
        case bundleID(String)         // NSWorkspace.runningApplications
        case commandExists(String)    // `which <cmd>` returns 0
        case directoryExists(String)  // FileManager.fileExists
        case always                   // Always show (e.g., system-level)
    }

    struct DiskScan: Identifiable {
        let id = UUID()
        let label: String
        let path: String              // Supports ~ expansion
        let maxDepth: Int
        let safeToDelete: Bool
        let warningMessage: String?
    }

    struct CleanupAction: Identifiable {
        let id = UUID()
        let label: String
        let shellCommand: String
        let safetyLevel: SafetyLevel
        let estimatedSavingsHint: String?
        let requiresConfirmation: Bool

        enum SafetyLevel {
            case safe           // Green — no data loss possible
            case moderate       // Orange — rebuilds automatically
            case destructive    // Red — data cannot be recovered
        }
    }
}
```

### 4.2 Built-in Profiles Registry
Create `MemoryMonitor/Sources/Services/BuiltinProfiles.swift`:

```swift
enum BuiltinProfiles {
    static let all: [DeveloperProfile] = [
        xcode, docker, node, opencode,
        python, vscode, homebrew, git,
        androidStudio, jetbrains
    ]

    static let xcode = DeveloperProfile(
        id: "xcode",
        name: "Xcode",
        icon: "hammer.fill",
        color: .blue,
        category: .appleTools,
        detectMethod: .bundleID("com.apple.dt.Xcode"),
        memoryProcessPatterns: [
            "XcodeBuildService",
            "swift-frontend",
            "clang",
            "com.apple.dt.SKAgent"
        ],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "DerivedData",
                path: "~/Library/Developer/Xcode/DerivedData",
                maxDepth: 2,
                safeToDelete: true,
                warningMessage: "Xcode will rebuild on next build. Increases first build time."
            ),
            DeveloperProfile.DiskScan(
                label: "Archives",
                path: "~/Library/Developer/Xcode/Archives",
                maxDepth: 2,
                safeToDelete: false,
                warningMessage: "Archives contain your app binaries. Only delete if backed up."
            ),
            DeveloperProfile.DiskScan(
                label: "iOS Device Support",
                path: "~/Library/Developer/Xcode/iOS DeviceSupport",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean DerivedData",
                shellCommand: "rm -rf ~/Library/Developer/Xcode/DerivedData/*",
                safetyLevel: .moderate,
                estimatedSavingsHint: "Usually 1–20 GB",
                requiresConfirmation: true
            ),
            DeveloperProfile.CleanupAction(
                label: "Remove Old Simulators",
                shellCommand: "xcrun simctl delete unavailable",
                safetyLevel: .safe,
                estimatedSavingsHint: "Varies",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Kill Build Daemons",
                shellCommand: "pkill -x XcodeBuildService; pkill -x swift-frontend",
                safetyLevel: .moderate,
                estimatedSavingsHint: "200–800 MB RAM",
                requiresConfirmation: true
            ),
        ],
        description: "Apple's IDE and build system. DerivedData and device support can grow to 30+ GB."
    )

    static let docker = DeveloperProfile(
        id: "docker",
        name: "Docker",
        icon: "cube.box.fill",
        color: .cyan,
        category: .containers,
        detectMethod: .processName("com.docker.backend"),
        memoryProcessPatterns: ["com.docker.backend", "containerd", "docker"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Docker Data",
                path: "~/Library/Containers/com.docker.docker/Data",
                maxDepth: 1,
                safeToDelete: false,
                warningMessage: "Contains all images and containers."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Remove Stopped Containers",
                shellCommand: "/usr/local/bin/docker container prune -f",
                safetyLevel: .safe,
                estimatedSavingsHint: "Varies",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Remove Dangling Images",
                shellCommand: "/usr/local/bin/docker image prune -f",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 5 GB",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Full System Prune",
                shellCommand: "/usr/local/bin/docker system prune -f --volumes",
                safetyLevel: .destructive,
                estimatedSavingsHint: "1–20 GB",
                requiresConfirmation: true
            ),
        ],
        description: "Container runtime. Unused images and volumes accumulate rapidly."
    )

    static let node = DeveloperProfile(
        id: "node",
        name: "Node / npm",
        icon: "cube.transparent.fill",
        color: .green,
        category: .languages,
        detectMethod: .commandExists("node"),
        memoryProcessPatterns: ["node", "npm"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "npm cache",
                path: "~/.npm",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
            DeveloperProfile.DiskScan(
                label: "yarn cache",
                path: "~/.yarn/cache",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
            DeveloperProfile.DiskScan(
                label: "pnpm store",
                path: "~/.pnpm-store",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean npm cache",
                shellCommand: "npm cache clean --force",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 3 GB",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Clean yarn cache",
                shellCommand: "yarn cache clean",
                safetyLevel: .safe,
                estimatedSavingsHint: "Varies",
                requiresConfirmation: false
            ),
        ],
        description: "JavaScript runtime. npm/yarn caches and node_modules directories grow fast."
    )

    static let opencode = DeveloperProfile(
        id: "opencode",
        name: "OpenCode",
        icon: "terminal.fill",
        color: .purple,
        category: .editors,
        detectMethod: .processName("opencode"),
        memoryProcessPatterns: ["opencode"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "OpenCode DB",
                path: "~/.local/share/opencode/opencode.db",
                maxDepth: 0,
                safeToDelete: false,
                warningMessage: "Contains session history. Vacuum will compact it."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Vacuum DB",
                shellCommand: """
                    sqlite3 ~/.local/share/opencode/opencode.db \
                    "DELETE FROM part WHERE session_id NOT IN \
                    (SELECT id FROM session ORDER BY time_updated DESC LIMIT 3); \
                    DELETE FROM session WHERE id NOT IN \
                    (SELECT id FROM session ORDER BY time_updated DESC LIMIT 3); \
                    VACUUM;"
                    """,
                safetyLevel: .moderate,
                estimatedSavingsHint: "Up to 500 MB",
                requiresConfirmation: true
            ),
            DeveloperProfile.CleanupAction(
                label: "Kill Standalone Sessions",
                shellCommand: "pkill -f 'opencode' || true",
                safetyLevel: .moderate,
                estimatedSavingsHint: "200–800 MB RAM",
                requiresConfirmation: true
            ),
        ],
        description: "AI coding assistant. DB grows with session history; standalone sessions waste RAM."
    )

    static let python = DeveloperProfile(
        id: "python",
        name: "Python",
        icon: "doc.text.fill",
        color: .yellow,
        category: .languages,
        detectMethod: .commandExists("python3"),
        memoryProcessPatterns: ["python", "python3", "jupyter"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "pip cache",
                path: "~/Library/Caches/pip",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean pip cache",
                shellCommand: "pip3 cache purge",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 2 GB",
                requiresConfirmation: false
            ),
        ],
        description: "Python interpreter. pip cache accumulates downloaded packages."
    )

    static let vscode = DeveloperProfile(
        id: "vscode",
        name: "VS Code",
        icon: "chevron.left.forwardslash.chevron.right",
        color: .blue,
        category: .editors,
        detectMethod: .bundleID("com.microsoft.VSCode"),
        memoryProcessPatterns: ["Electron", "Code Helper"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Extension Cache",
                path: "~/.vscode/extensions",
                maxDepth: 1,
                safeToDelete: false,
                warningMessage: "Contains installed extensions."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clear Workspace Storage",
                shellCommand: "rm -rf ~/Library/Application\\ Support/Code/User/workspaceStorage/*",
                safetyLevel: .moderate,
                estimatedSavingsHint: "100 MB – 1 GB",
                requiresConfirmation: true
            ),
        ],
        description: "Electron-based editor. Workspace storage and extension caches accumulate over time."
    )

    static let homebrew = DeveloperProfile(
        id: "homebrew",
        name: "Homebrew",
        icon: "flask.fill",
        color: .orange,
        category: .packageManagers,
        detectMethod: .commandExists("brew"),
        memoryProcessPatterns: [],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Homebrew Cache",
                path: "~/Library/Caches/Homebrew",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "brew cleanup",
                shellCommand: "/opt/homebrew/bin/brew cleanup --prune=all",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 5 GB",
                requiresConfirmation: false
            ),
        ],
        description: "macOS package manager. Old formula versions and downloads pile up."
    )

    static let git = DeveloperProfile(
        id: "git",
        name: "Git",
        icon: "arrow.triangle.branch",
        color: .red,
        category: .versionControl,
        detectMethod: .commandExists("git"),
        memoryProcessPatterns: ["git"],
        diskScans: [],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "GC all repos in ~/Projects",
                shellCommand: """
                    find ~/Projects -maxdepth 3 -name ".git" -type d \
                    -exec sh -c 'cd "$(dirname "{}")" && git gc --prune=now --quiet' \\;
                    """,
                safetyLevel: .safe,
                estimatedSavingsHint: "10–200 MB",
                requiresConfirmation: false
            ),
        ],
        description: "Version control. git gc compresses pack objects and removes unreachable objects."
    )

    static let androidStudio = DeveloperProfile(
        id: "android-studio",
        name: "Android Studio",
        icon: "app.badge.fill",
        color: .green,
        category: .editors,
        detectMethod: .bundleID("com.google.android.studio"),
        memoryProcessPatterns: ["studio", "java", "gradle"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Gradle Cache",
                path: "~/.gradle/caches",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: "Gradle will re-download dependencies on next build."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean Gradle Cache",
                shellCommand: "rm -rf ~/.gradle/caches",
                safetyLevel: .moderate,
                estimatedSavingsHint: "500 MB – 10 GB",
                requiresConfirmation: true
            ),
        ],
        description: "Android IDE. Gradle caches and build outputs consume significant disk."
    )

    static let jetbrains = DeveloperProfile(
        id: "jetbrains",
        name: "JetBrains IDEs",
        icon: "diamond.fill",
        color: .pink,
        category: .editors,
        detectMethod: .directoryExists("~/Library/Application Support/JetBrains"),
        memoryProcessPatterns: ["idea", "pycharm", "webstorm", "goland", "clion", "rider"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "JetBrains Caches",
                path: "~/Library/Caches/JetBrains",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clear IDE Caches",
                shellCommand: "rm -rf ~/Library/Caches/JetBrains/*",
                safetyLevel: .moderate,
                estimatedSavingsHint: "200 MB – 3 GB",
                requiresConfirmation: true
            ),
        ],
        description: "JetBrains IDE suite. Index caches and build artifacts accumulate quickly."
    )
}
```

### 4.3 DeveloperProfilesEngine
Create `MemoryMonitor/Sources/Services/DeveloperProfilesEngine.swift`:

```swift
import Foundation
import AppKit
import Combine

class DeveloperProfilesEngine: ObservableObject {
    static let shared = DeveloperProfilesEngine()

    @Published var profileStates: [ProfileState] = []
    @Published var customRules: [CustomRule] = []
    @Published var isRefreshing = false

    struct ProfileState: Identifiable {
        let id: String
        let profile: DeveloperProfile
        var isDetected: Bool       // Tool is installed
        var isRunning: Bool        // Process is currently running
        var memoryMB: Double       // Total RSS of matching processes
        var diskSizes: [String: Double]  // DiskScan.label → MB
        var totalDiskMB: Double
        var lastUpdated: Date
    }

    struct CustomRule: Identifiable, Codable {
        let id: UUID
        var name: String
        var icon: String           // SF Symbol name
        var cleanupCommand: String
        var description: String

        init(name: String, icon: String, cleanupCommand: String, description: String) {
            self.id = UUID()
            self.name = name
            self.icon = icon
            self.cleanupCommand = cleanupCommand
            self.description = description
        }
    }

    private let workQueue = DispatchQueue(label: "com.pulse.devprofiles", qos: .utility)

    private init() {
        loadCustomRules()
        // Initial refresh
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        DispatchQueue.main.async { self.isRefreshing = true }

        workQueue.async { [weak self] in
            guard let self else { return }
            let psOutput = self.runPS()
            var states: [ProfileState] = []

            for profile in BuiltinProfiles.all {
                let isDetected = self.detect(profile.detectMethod)
                guard isDetected else { continue }  // Only show installed tools

                let isRunning = self.isRunning(profile, psOutput: psOutput)
                let memoryMB = self.measureMemory(profile, psOutput: psOutput)
                var diskSizes: [String: Double] = [:]
                var totalDisk: Double = 0

                for scan in profile.diskScans {
                    let sizeMB = self.estimateDirectorySize(path: scan.path)
                    diskSizes[scan.label] = sizeMB
                    totalDisk += sizeMB
                }

                states.append(ProfileState(
                    id: profile.id,
                    profile: profile,
                    isDetected: true,
                    isRunning: isRunning,
                    memoryMB: memoryMB,
                    diskSizes: diskSizes,
                    totalDiskMB: totalDisk,
                    lastUpdated: Date()
                ))
            }

            DispatchQueue.main.async {
                self.profileStates = states
                self.isRefreshing = false
            }
        }
    }

    func executeAction(_ action: DeveloperProfile.CleanupAction) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            workQueue.async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                task.arguments = ["-c", action.shellCommand]
                let outPipe = Pipe()
                let errPipe = Pipe()
                task.standardOutput = outPipe
                task.standardError = errPipe
                do {
                    try task.run()
                    task.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let success = task.terminationStatus == 0
                    continuation.resume(returning: (success, success ? out : err))
                } catch {
                    continuation.resume(returning: (false, error.localizedDescription))
                }
            }
        }
    }

    func addCustomRule(_ rule: CustomRule) {
        customRules.append(rule)
        saveCustomRules()
    }

    func removeCustomRule(id: UUID) {
        customRules.removeAll { $0.id == id }
        saveCustomRules()
    }

    // MARK: - Private

    private func detect(_ method: DeveloperProfile.DetectMethod) -> Bool {
        switch method {
        case .always: return true
        case .processName(let name):
            return !runShell("pgrep -qx \(name)").isEmpty || runShellStatus("pgrep -qx \(name)") == 0
        case .bundleID(let id):
            return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == id }
                || NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
        case .commandExists(let cmd):
            return runShellStatus("which \(cmd)") == 0
        case .directoryExists(let path):
            let expanded = (path as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: expanded)
        }
    }

    private func isRunning(_ profile: DeveloperProfile, psOutput: String) -> Bool {
        for pattern in profile.memoryProcessPatterns {
            if psOutput.lowercased().contains(pattern.lowercased()) { return true }
        }
        return false
    }

    private func measureMemory(_ profile: DeveloperProfile, psOutput: String) -> Double {
        var total: Double = 0
        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for pattern in profile.memoryProcessPatterns {
                if trimmed.lowercased().contains(pattern.lowercased()) {
                    let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    if let rssKB = Double(parts.first ?? "") {
                        total += rssKB / 1024
                    }
                }
            }
        }
        return total
    }

    private func estimateDirectorySize(path: String) -> Double {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return 0 }
        var totalBytes: Int64 = 0
        let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: expanded),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var count = 0
        for case let url as URL in (enumerator ?? .init()) {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory == false else { continue }
            totalBytes += Int64(values.fileSize ?? 0)
            count += 1
            if count > 50_000 { break }
        }
        return Double(totalBytes) / (1024 * 1024)
    }

    private func runPS() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "rss=,command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    @discardableResult
    private func runShell(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private func runShellStatus(_ command: String) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus
    }

    private func loadCustomRules() {
        if let data = UserDefaults.standard.data(forKey: "customDevRules"),
           let decoded = try? JSONDecoder().decode([CustomRule].self, from: data) {
            customRules = decoded
        }
    }

    private func saveCustomRules() {
        if let encoded = try? JSONEncoder().encode(customRules) {
            UserDefaults.standard.set(encoded, forKey: "customDevRules")
        }
    }
}
```

### 4.4 DeveloperView Redesign
Replace `DeveloperView.swift` entirely with a profiles-based layout:

```swift
import SwiftUI

struct DeveloperView: View {
    @ObservedObject var engine = DeveloperProfilesEngine.shared
    @State private var confirmAction: DeveloperProfile.CleanupAction?
    @State private var confirmProfile: DeveloperProfile?
    @State private var isExecuting = false
    @State private var lastResult: String?
    @State private var showAddCustomRule = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader

            if engine.isRefreshing && engine.profileStates.isEmpty {
                loadingState
            } else if engine.profileStates.isEmpty {
                emptyState
            } else {
                profilesList
            }

            customRulesSection
        }
        .onAppear { engine.refresh() }
    }
    // ... (profile cards, cleanup action buttons, custom rule form)
    // Each profile card shows:
    //   - Profile icon + name + category badge
    //   - "Running" indicator if process detected
    //   - Memory usage if running (e.g., "1.2 GB RAM")
    //   - Disk breakdown (e.g., "DerivedData: 14.3 GB")
    //   - Cleanup action buttons with safety level color coding
}
```

---

## 5. Track 2 — UI Premium Redesign

### 5.1 Menu Bar Popover Improvements
**File:** `App.swift` — `MenuBarPopoverContent`

Changes:
1. Add Disk to `quickStatsSection` (currently only Memory + CPU + Disk — Disk is already there, confirm it shows)
2. Replace battery display with new `BatteryStatusView` component
3. Show charging bolt when `isCharging == true`
4. Animate the "Optimize" button result: show a green checkmark + freed MB for 5s after completion
5. Add animated number transitions on `MiniStatCard` values using `.contentTransition(.numericText())`

### 5.2 Menu Bar Label Enhancement
**File:** `App.swift` — `MenuBarLabel`

Add support for all `MenuBarDisplayMode` options, including `compact` showing both memory % and CPU %:
```swift
var body: some View {
    HStack(spacing: 4) {
        Image(systemName: manager.menuBarIcon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(pressureColor)
            .font(.system(size: 12, weight: .semibold))

        if settings.menuBarDisplayMode == .compact {
            HStack(spacing: 3) {
                Text(memText)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(cpuText)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(pressureColor)
        } else {
            Text(manager.menuBarText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pressureColor)
        }
    }
}
```

### 5.3 Dashboard Top Bar
**File:** `DashboardView.swift`

1. Replace the `Battery` icon in sidebar with the new `BatteryStatusView` component
2. Add Settings gear button to top bar (right side)
3. Remove Settings from sidebar tab list
4. Apply `DesignSystem.Colors.score()` instead of the local `scoreColor` computed var
5. Add `.contentTransition(.numericText())` to health score text

### 5.4 Sidebar Improvements
**File:** `DashboardView.swift`

1. Increase sidebar width: `72` → `80`
2. Add a thin color accent bar on the leading edge of the selected tab button
3. Increase tab icon size: `16` → `18`
4. Use SF Symbol `.fill` suffix for active tab icons (most already do this)

### 5.5 HealthView Vitality Orb
The `VitalityOrb` component referenced in `HealthView` must exist and implement:
- A breathing animation (scale 0.98 ↔ 1.0, period 3s) when health is good (score > 80)
- A pulsing animation (faster, scale 0.96 ↔ 1.04) when health is degraded
- Gradient arc: green (score 90+) → blue (80-89) → yellow (70-79) → orange (50-69) → red (<50)
- Center shows the letter grade in SF Rounded Bold, score number below it
- A soft glow shadow matching the gradient color

If `VitalityOrb` is missing from the codebase, create `MemoryMonitor/Sources/Views/Components/VitalityOrb.swift`.

### 5.6 Loading Skeleton State
Create `MemoryMonitor/Sources/Views/Components/SkeletonView.swift`:

```swift
struct SkeletonModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.04),
                        Color.primary.opacity(0.12),
                        Color.primary.opacity(0.04)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier())
            .opacity(isLoading ? 1 : 0)
            .overlay(opacity(isLoading ? 0 : 1))
    }
}
```

Use in `MemorySection` and `HealthView`: wrap gauges in `.skeleton(isLoading: systemMonitor.currentMemory == nil)`.

### 5.7 ProcessListView Sort Persistence
**File:** `ProcessListView.swift`

```swift
@AppStorage("processSortField")     private var sortField: String = "memory"
@AppStorage("processSortAscending") private var sortAscending: Bool = false
```

Restore sort state in `onAppear` and persist on column header tap.

### 5.8 ActionToastView Improvements
**File:** `ActionToastView.swift`

The toast must:
1. Show progress bar during optimization (tied to `manager.optimizer.progress`)
2. Transition to success state (green checkmark + "X MB freed") on completion
3. Auto-dismiss after 5s
4. Support tap-to-dismiss
5. Position at bottom center of the content area (not bottom of window)

### 5.9 Charts: Confirm Swift Charts Usage
**Files:** `MemoryHistoryView.swift`, `CPUView.swift`, `NetworkView.swift`

Confirm all history charts use `import Charts` (Swift Charts framework, macOS 13+). If any use custom `Canvas` drawing:
- Replace with `Chart { ForEach(...) { LineMark(...) } }`
- Add `.chartXAxis(.hidden)` and `.chartYAxis` with percentage formatting
- Add `.interpolationMethod(.catmullRom)` for smooth curves
- Use `.foregroundStyle(LinearGradient(...))` for area fill under the line

---

## 6. New Files Summary

| File | Purpose |
|---|---|
| `Sources/Utilities/HapticFeedback.swift` | macOS haptic feedback wrapper |
| `Sources/Views/Components/BatteryStatusView.swift` | Reusable battery display component |
| `Sources/Views/Components/VitalityOrb.swift` | Breathing health score orb (if missing) |
| `Sources/Views/Components/SkeletonView.swift` | Loading placeholder modifier |
| `Sources/Views/SystemView.swift` | CPU + Disk + Network + Battery (replaces MoreView) |
| `Sources/Views/OptimizerView.swift` | Process list + Guard + Cleanup engine |
| `Sources/Views/DeveloperView.swift` | Profiles-based dev tool view (full rewrite) |
| `Sources/Models/DeveloperProfile.swift` | Profile data model |
| `Sources/Services/BuiltinProfiles.swift` | 10 built-in dev tool profiles |
| `Sources/Services/DeveloperProfilesEngine.swift` | Profile detection + execution engine |

---

## 7. Files to Delete / Clean Up

| File | Action |
|---|---|
| `MoreView` struct in `DashboardView.swift` | Delete — content moved to `SystemView` + `OptimizerView` |
| `openWindow(_:)` helper in `MenuBarPopoverContent` | Delete — replaced by `@Environment(\.openWindow)` |
| `scoreColor` computed var in `MenuBarPopoverContent`, `DashboardView`, `HealthView` | Delete all 3 — replaced by `DesignSystem.Colors.score()` |
| `batteryIcon` + `batteryColor` in `MenuBarPopoverContent`, `DashboardView` | Delete both — replaced by `BatteryStatusView` |
| Brand color properties in `Brand.swift` (`neutralTint`, `accentTint`, `successTint`, `warningTint`, `dangerTint`) | Delete — duplicates of `DesignSystem.Colors` |

---

## 8. Testing Requirements

Create a `Tests/` directory at the package root. Add to `Package.swift`:
```swift
.testTarget(
    name: "PulseTests",
    dependencies: ["MemoryMonitor"],
    path: "Tests"
)
```

### 8.1 Required Test Cases

**`Tests/HealthScoreTests.swift`**
- Score is 100 when all metrics nominal
- Score deducts correctly for high memory (>75%, >85%, >95%)
- Score deducts correctly for swap (>1 GB, >2 GB, >5 GB)
- Score deducts correctly for CPU (>50%, >80%)
- Score deducts correctly for thermal (Serious, Critical)
- Score is never negative (min 0)
- Grade maps correctly (A=90+, B=80-89, C=70-79, D=50-69, F=<50)

**`Tests/SecurityScannerTests.swift`**
- `checkSuspicious(label:program:)` correctly flags known suspicious keywords
- `checkSuspicious` does not flag Apple bundle IDs
- `checkSuspicious` does not flag known safe bundle IDs
- Running from `/tmp/` path is flagged as suspicious
- Hidden path (`/.hidden`) is flagged as suspicious
- `calculateOverallRisk` returns `.critical` when keylogger is `.high`
- Keylogger loop fix: safe bundle IDs correctly skipped (regression test for the `continue` bug)

**`Tests/DeveloperProfilesTests.swift`**
- Profile detection returns false for non-existent tool
- Memory measurement correctly sums RSS from mock ps output
- Directory size estimation handles non-existent paths gracefully
- Custom rule serialization round-trips correctly (encode → decode)

**`Tests/AppSettingsTests.swift`**
- Alert thresholds sanitize legacy values correctly
- `sanitizedThresholds` rejects non-standard percentages
- `sanitizedThresholds` rejects threshold counts != 3

---

## 9. Implementation Phases

### Phase 0 — Foundation (do first, no dependencies)
**Goal:** App builds cleanly with correct branding. All critical bugs that cause build errors or API crashes fixed.

Tasks (in order):
1. Create `HapticFeedback.swift` (fixes build error)
2. Update `WindowGroup("Memory Monitor")` → `WindowGroup("Pulse")` in `App.swift`
3. Remove Brand color properties from `Brand.swift`
4. Add semantic colors and `score()` + `battery()` helpers to `DesignSystem.Colors`
5. Replace `NSUserNotification` with `UNUserNotificationCenter` in `AlertManager.swift`
6. Replace `NSUserNotification` with `UNUserNotificationCenter` in `SecurityScanner.swift`
7. Add `UNUserNotificationCenter.requestAuthorization` call in `AppDelegate.applicationDidFinishLaunching`
8. Fix `NSApp.setActivationPolicy(.regular)` → `.accessory` in `AppDelegate`
9. Fix double `showMainWindow()` — remove from `applicationDidBecomeActive`
10. **Verify:** `swift build` succeeds with 0 errors

### Phase 1 — Engine Correctness (Track 1)
**Goal:** All engine bugs fixed. Monitoring is accurate, safe, and uses modern APIs.

Tasks (in order):
1. Add kernel memory pressure monitoring via `DispatchSource.makeMemoryPressureSource` to `SystemMemoryMonitor.swift`
2. Unify swap reading — `DeveloperMonitor.readSwap()` reads from `SystemMemoryMonitor.shared`
3. Fix `SecurityScanner.checkForKeyloggers()` — replace TCC.db approach with NSWorkspace + optional FDA fallback
4. Fix keylogger loop `continue` bug (regression test in Phase 4)
5. Add `hasTCCAccess` published property to `SecurityScanner`
6. Wire `SMAppService.mainApp.register/unregister` to `AppSettings.launchAtLogin` didSet
7. Call `syncLaunchAtLoginStatus()` at end of `AppSettings.init()`
8. Replace polling loops in `MemoryOptimizer` with Combine-based `waitForComprehensiveCompletion`
9. Fix `openWindow()` in `MenuBarPopoverContent` — use `@Environment(\.openWindow)` + give `WindowGroup` id `"main"`
10. **Verify:** Build succeeds. Run app. Confirm memory pressure updates, launch at login toggle works, optimize does not block main thread.

### Phase 2 — Developer Profiles System (Track 1, new feature)
**Goal:** Developer tab transformed from OpenCode-specific to generic profiles engine.

Tasks (in order):
1. Create `Models/DeveloperProfile.swift`
2. Create `Services/BuiltinProfiles.swift` with all 10 profiles
3. Create `Services/DeveloperProfilesEngine.swift`
4. Rewrite `Views/DeveloperView.swift` to use `DeveloperProfilesEngine`
5. Wire `DeveloperProfilesEngine.shared` into `MemoryMonitorManager.setupBindings()` (add to child publishers)
6. Remove OpenCode-specific hardcoded logic from `HealthView.primaryIssue` — it should come from `DeveloperProfilesEngine` profile state for the OpenCode profile
7. **Verify:** Build succeeds. Run app. Developer tab shows detected tools (at minimum: Homebrew, Git, Node if installed). OpenCode profile appears if opencode is running.

### Phase 3 — Navigation + UI Restructure (Track 2)
**Goal:** Navigation is clean, semantic, and consistent with Pulse brand.

Tasks (in order):
1. Create `Views/SystemView.swift` with CPU + Disk + Network + Battery content
2. Create `Views/OptimizerView.swift` with ProcessList + AutoKill + CleanupStats content
3. Update `DashboardView.Tab` enum to: `health, memory, system, optimizer, developer, security`
4. Remove `MoreView` struct from `DashboardView.swift`
5. Add Settings gear button to top bar in `DashboardView`
6. Remove Settings from sidebar tab list
7. Extract `scoreColor` to `DesignSystem.Colors.score()` — update all 3 call sites
8. Create `Views/Components/BatteryStatusView.swift`
9. Remove duplicate `batteryIcon`/`batteryColor` from `MenuBarPopoverContent` and `DashboardView`
10. Remove nested `ScrollView` from `HealthView.body`
11. Remove nested `ScrollView` from `SecurityView.body`, `DeveloperView.body` if present
12. Increase sidebar width to `80`, increase tab icon size to `18`
13. **Verify:** All 6 tabs navigate correctly. Settings window opens via Cmd+,. No scroll conflicts.

### Phase 4 — Premium UI Polish (Track 2)
**Goal:** Every view looks and feels premium. Pulse brand is consistent throughout.

Tasks (in order):
1. Replace all raw `Color.blue/.orange/.red/.green/.purple/.cyan` in metric contexts with `DesignSystem.Colors.memory/.cpu/.disk/.network/.battery`
2. Confirm `VitalityOrb` exists and implements breathing + pulse animation
3. Create `Views/Components/SkeletonView.swift` — apply to Memory gauge and Health bento grid
4. Add `.contentTransition(.numericText())` to all live-updating numeric text views
5. Improve `ActionToastView` — add progress bar, success state, auto-dismiss
6. Improve `MenuBarPopoverContent` — add `.contentTransition(.numericText())` to stat cards
7. Improve `MenuBarLabel` — implement compact mode with both Memory % and CPU %
8. Add charging bolt to `BatteryStatusView`
9. Confirm all history charts use Swift Charts with `.interpolationMethod(.catmullRom)` and gradient area fill
10. Add sort persistence (`@AppStorage`) to `ProcessListView`
11. Add "Grant Full Disk Access" hint to `SecurityView` when `scanner.hasTCCAccess == false`
12. **Verify:** Visual review of all 6 tabs in light and dark mode. All number transitions are smooth. Skeleton shows on first launch before data arrives.

### Phase 5 — Tests + Distribution (final)
**Goal:** Confidence in engine correctness. App ready for GitHub release.

Tasks (in order):
1. Add `Tests/` directory and test target to `Package.swift`
2. Write `HealthScoreTests.swift` (7 test cases from §8.1)
3. Write `SecurityScannerTests.swift` (8 test cases from §8.1)
4. Write `DeveloperProfilesTests.swift` (4 test cases from §8.1)
5. Write `AppSettingsTests.swift` (3 test cases from §8.1)
6. Run `swift test` — all must pass
7. Update `README.md`: rename to Pulse, update features list, update build instructions
8. Add `build/Info.plist` with `LSUIElement = YES` (hides Dock icon at launch before `.accessory` policy takes effect) and `CFBundleDisplayName = Pulse`
9. Add `build/Pulse.entitlements` with: `com.apple.security.app-sandbox = false`, `com.apple.security.files.user-selected.read-write = true`
10. Add GitHub Actions workflow `.github/workflows/ci.yml`:
    ```yaml
    on: [push, pull_request]
    jobs:
      build:
        runs-on: macos-14
        steps:
          - uses: actions/checkout@v4
          - run: swift build -c release
          - run: swift test
    ```
11. **Final verify:** `swift build -c release` succeeds. `swift test` passes. App launches, menu bar icon appears, all 6 tabs load correctly.

---

## 10. File Touch List (Complete)

### New files to create:
- `MemoryMonitor/Sources/Utilities/HapticFeedback.swift`
- `MemoryMonitor/Sources/Views/Components/BatteryStatusView.swift`
- `MemoryMonitor/Sources/Views/Components/VitalityOrb.swift` (if missing)
- `MemoryMonitor/Sources/Views/Components/SkeletonView.swift`
- `MemoryMonitor/Sources/Views/SystemView.swift`
- `MemoryMonitor/Sources/Views/OptimizerView.swift`
- `MemoryMonitor/Sources/Models/DeveloperProfile.swift`
- `MemoryMonitor/Sources/Services/BuiltinProfiles.swift`
- `MemoryMonitor/Sources/Services/DeveloperProfilesEngine.swift`
- `Tests/PulseTests/HealthScoreTests.swift`
- `Tests/PulseTests/SecurityScannerTests.swift`
- `Tests/PulseTests/DeveloperProfilesTests.swift`
- `Tests/PulseTests/AppSettingsTests.swift`
- `.github/workflows/ci.yml`
- `build/Info.plist`
- `build/Pulse.entitlements`

### Files to modify:
- `Package.swift` — add test target
- `README.md` — rebrand to Pulse, update features + build instructions
- `MemoryMonitor/Sources/App.swift` — WindowGroup id, openWindow, activation policy, AppDelegate fixes, UNUserNotificationCenter request
- `MemoryMonitor/Sources/Models/Brand.swift` — remove color properties
- `MemoryMonitor/Sources/Models/AppSettings.swift` — SMAppService launch at login wiring
- `MemoryMonitor/Sources/Utilities/DesignSystem.swift` — add semantic colors + score() + battery() helpers
- `MemoryMonitor/Sources/Services/SystemMemoryMonitor.swift` — kernel pressure source
- `MemoryMonitor/Sources/Services/DeveloperMonitor.swift` — unify swap reading
- `MemoryMonitor/Sources/Services/MemoryMonitorManager.swift` — wire DeveloperProfilesEngine
- `MemoryMonitor/Sources/Services/AlertManager.swift` — UNUserNotificationCenter
- `MemoryMonitor/Sources/Services/SecurityScanner.swift` — keylogger fix + TCC approach + hasTCCAccess + UNUserNotificationCenter
- `MemoryMonitor/Sources/Services/MemoryOptimizer.swift` — Combine-based completion
- `MemoryMonitor/Sources/Views/DashboardView.swift` — new Tab enum, settings button, remove MoreView, BatteryStatusView
- `MemoryMonitor/Sources/Views/HealthView.swift` — remove ScrollView, remove inline scoreColor
- `MemoryMonitor/Sources/Views/DeveloperView.swift` — full rewrite to profiles
- `MemoryMonitor/Sources/Views/SecurityView.swift` — remove ScrollView, add FDA hint
- `MemoryMonitor/Sources/Views/ProcessListView.swift` — sort persistence
- `MemoryMonitor/Sources/Views/ActionToastView.swift` — progress bar + success state

### Files to leave untouched:
- `MemoryMonitor/Sources/Models/MemoryTypes.swift` — correct as-is
- `MemoryMonitor/Sources/Services/ComprehensiveOptimizer.swift` — internals correct; only accessed via MemoryOptimizer
- `MemoryMonitor/Sources/Services/StorageAnalyzer.swift` — correct as-is
- `MemoryMonitor/Sources/Services/TimeMachineManager.swift` — correct as-is
- `MemoryMonitor/Sources/Services/AutoKillManager.swift` — correct as-is
- `MemoryMonitor/Sources/Services/CPUMonitor.swift` — correct as-is
- `MemoryMonitor/Sources/Services/DiskMonitor.swift` — correct as-is
- `MemoryMonitor/Sources/Services/ProcessMemoryMonitor.swift` — correct as-is
- `MemoryMonitor/Sources/Services/SystemHealthMonitor.swift` — correct as-is
- `MemoryMonitor/Sources/Views/MemoryGaugeView.swift` — correct as-is
- `MemoryMonitor/Sources/Views/MemoryBreakdownView.swift` — correct as-is
- `MemoryMonitor/Sources/Views/MemoryHistoryView.swift` — verify Charts usage
- `MemoryMonitor/Sources/Views/CPUView.swift` — leave; moved to SystemView as child
- `MemoryMonitor/Sources/Views/DiskView.swift` — leave; moved to SystemView as child
- `MemoryMonitor/Sources/Views/NetworkView.swift` — leave; moved to SystemView as child
- `MemoryMonitor/Sources/Views/BatteryThermalView.swift` — leave; moved to SystemView as child
- `MemoryMonitor/Sources/Views/AutoKillView.swift` — leave; moved to OptimizerView as child
- `MemoryMonitor/Sources/Views/CleanupConfirmationView.swift` — correct as-is
- `MemoryMonitor/Sources/Views/CleanupStatsView.swift` — leave; used in OptimizerView
- `MemoryMonitor/Sources/Views/SmartSuggestionsView.swift` — correct as-is
- `MemoryMonitor/Sources/Views/MenuBarLiteView.swift` — correct as-is
- `MemoryMonitor/Sources/Views/SettingsView.swift` — correct as-is
- `MemoryMonitor/Sources/Views/Animations.swift` — correct as-is
- `MemoryMonitor/Sources/Views/HealthScoreView.swift` — verify if still used
- `MemoryMonitor/Sources/Utilities/NavigationManager.swift` — verify if still used

---

## 11. Constraints for Executor

1. **Never modify files listed in "leave untouched"** unless a direct dependency requires it.
2. **Each phase must build before starting the next.** Run `swift build` at the end of each phase.
3. **No new dependencies.** Only Apple frameworks (SwiftUI, Combine, ServiceManagement, UserNotifications, Charts, AppKit, Foundation, Darwin).
4. **Immutability:** All new model types must use `let` properties. Mutations only via `MemoryMonitorManager` or engine classes.
5. **Thread safety:** All `@Published` updates must happen on `DispatchQueue.main` or be marked `@MainActor`.
6. **Error handling:** No silent `try?` on operations that affect user data (cleanup, disable persistence item). Surface errors to the UI.
7. **No hardcoded paths** outside of `BuiltinProfiles.swift`. All paths use `~` expansion or `FileManager.default.homeDirectoryForCurrentUser`.
8. **Test before marking phase complete.** Every phase ends with a build check. Phase 5 ends with `swift test` passing.
