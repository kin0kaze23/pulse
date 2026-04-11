# Phase 3: Enhanced Features Implementation Plan

**Date:** March 31, 2026
**Lane:** STANDARD (with HIGH-RISK components)
**Risk Score:** 5/10
**Verification Profile:** ui-surface

---

## Executive Summary

Phase 3 delivers **4 enhanced features** that add polish and advanced functionality to Pulse:

1. **Trigger History UI** — Visual timeline of automation events
2. **Large File Finder** — Identify space consumers with safe deletion
3. **Privacy Permissions Audit** — Review and manage app permissions
4. **Menu Bar Quick Actions** — One-click cleanup from menu bar

**Phase 2 Status:** ✅ COMPLETE (118/119 tests passing, critical bug fixed)

---

## Feature Priority & Dependencies

```
Phase 3 Implementation Order:

┌─────────────────────────────────────────────────────────┐
│  1. Trigger History UI (Foundation for automation UX)   │
│     Depends on: SmartTriggerMonitor event logging       │
│     Risk: LOW | Effort: MEDIUM                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  2. Large File Finder (High user value feature)         │
│     Depends on: ComprehensiveOptimizer integration       │
│     Risk: MEDIUM (destructive operations)               │
│     Effort: MEDIUM                                       │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  3. Privacy Permissions Audit (Security enhancement)    │
│     Depends on: SecurityScanner foundation              │
│     Risk: MEDIUM (TCC/access considerations)            │
│     Effort: MEDIUM                                       │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  4. Menu Bar Quick Actions (Polish & convenience)       │
│     Depends on: None (independent feature)              │
│     Risk: LOW | Effort: SMALL                           │
└─────────────────────────────────────────────────────────┘
```

---

## Feature 1: Trigger History UI

### Objective

Provide users visibility into automation events with a visual timeline showing:
- When triggers fired (battery, memory, thermal)
- What action was taken (cleanup type, MB freed)
- Trends over time (daily/weekly trigger frequency)

### Technical Approach

**New Model: `TriggerEvent`**
```swift
struct TriggerEvent: Identifiable, Codable {
    let id: UUID
    let type: TriggerType  // battery, memory, thermal
    let timestamp: Date
    let freedMB: Double
    let systemState: SystemState  // battery%, memory%, thermalState
}

enum TriggerType: String, Codable {
    case battery = "Battery"
    case memory = "Memory"
    case thermal = "Thermal"
}

struct SystemState: Codable {
    let batteryPercentage: Double?
    let memoryUsedPercent: Double
    let thermalState: String  // nominal, fair, serious, critical
}
```

**New Service: `HistoricalMetricsService`**
```swift
class HistoricalMetricsService: ObservableObject {
    static let shared = HistoricalMetricsService()

    @Published var triggerEvents: [TriggerEvent] = []
    @Published var totalTriggersToday: Int = 0
    @Published var totalTriggersWeek: Int = 0
    @Published var totalFreedMBToday: Double = 0

    func logEvent(_ event: TriggerEvent)
    func getEvents(last24Hours: Bool) -> [TriggerEvent]
    func getTriggerFrequency(by type: TriggerType) -> Int
    func clearHistory()
}
```

**SmartTriggerMonitor Integration**
```swift
// In fireTrigger() method:
private func fireTrigger(type: String, action: () -> Void) {
    // ... existing cooldown check ...

    action()

    // NEW: Log to history
    let event = TriggerEvent(
        type: TriggerType(rawValue: type) ?? .memory,
        timestamp: Date(),
        freedMB: freedMB,
        systemState: SystemState(
            batteryPercentage: healthMonitor.batteryPercentage,
            memoryUsedPercent: systemMonitor.memoryUsedPercent,
            thermalState: healthMonitor.thermalState.description
        )
    )
    HistoricalMetricsService.shared.logEvent(event)
}
```

**New View: `TriggerHistoryView.swift`**
```swift
struct TriggerHistoryView: View {
    @StateObject private var metrics = HistoricalMetricsService.shared

    var body: some View {
        VStack {
            // Summary cards
            HStack {
                StatCard(title: "Today", value: "\(metrics.totalTriggersToday)")
                StatCard(title: "This Week", value: "\(metrics.totalTriggersWeek)")
                StatCard(title: "Freed Today", value: "\(metrics.totalFreedMBToday, .size)MB")
            }

            // Timeline
            List(metrics.triggerEvents) { event in
                TriggerEventRow(event: event)
            }

            // Filter controls
            Picker("Filter", selection: $selectedType) {
                Text("All").tag(TriggerType.all)
                Text("Battery").tag(TriggerType.battery)
                Text("Memory").tag(TriggerType.memory)
                Text("Thermal").tag(TriggerType.thermal)
            }
            .pickerStyle(.segmented)
        }
    }
}
```

### Files to Modify

| File | Action | Risk |
|------|--------|------|
| `Models/TriggerEvent.swift` | CREATE | LOW |
| `Services/HistoricalMetricsService.swift` | CREATE | MEDIUM |
| `Services/SmartTriggerMonitor.swift` | MODIFY | LOW |
| `Views/TriggerHistoryView.swift` | CREATE | LOW |
| `Views/SettingsView.swift` | MODIFY (add tab) | LOW |

### Success Criteria

- [ ] Trigger events logged to history
- [ ] Events persist to disk (JSON file in app support dir)
- [ ] UI shows timeline with filter controls
- [ ] Summary cards show today/week stats
- [ ] Clear history function available
- [ ] No performance impact on trigger firing

---

## Feature 2: Large File Finder

### Objective

Help users identify large files consuming disk space with:
- Scan by category (Downloads, Documents, Desktop, etc.)
- Sort by size/date/type
- Safe deletion with confirmation
- Protected paths whitelist

### Technical Approach

**New Model: `LargeFileScanResult`**
```swift
struct LargeFileScanResult: Identifiable {
    let id: UUID
    let url: URL
    let sizeMB: Double
    let fileType: FileType
    let lastModified: Date
    let isSafeToDelete: Bool
    let warning: String?  // e.g., "System file - deletion may cause issues"
}

enum FileType: String {
    case video = "Video"
    case audio = "Audio"
    case archive = "Archive"
    case diskImage = "Disk Image"
    case document = "Document"
    case application = "Application"
    case system = "System"
    case other = "Other"
}
```

**New Service: `LargeFileFinder`**
```swift
class LargeFileFinder: ObservableObject {
    static let shared = LargeFileFinder()

    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var results: [LargeFileScanResult] = []
    @Published var totalSizeFoundMB: Double = 0
    @Published var minimumSizeThresholdMB: Double = 100

    func scan(locations: [ScanLocation]) async
    func delete(file: LargeFileScanResult) async throws
    func moveToTrash(file: LargeFileScanResult) async throws

    enum ScanLocation {
        case downloads
        case documents
        case desktop
        case downloads
        case custom(URL)
    }
}
```

**Scan Algorithm**
```swift
func scan(locations: [ScanLocation]) async {
    var results: [LargeFileScanResult] = []

    for location in locations {
        let path = location.url
        let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.contentSizeKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        )

        for case let fileURL as URL in enumerator {
            let resources = try fileURL.resourceValues(forKeys: [
                .contentSizeKey, .contentTypeKey, .isDirectoryKey
            ])

            guard !resources.isDirectory else { continue }
            guard let size = resources.fileSize else { continue }
            guard size > minimumSizeThresholdMB * 1024 * 1024 else { continue }

            let fileType = determineFileType(fileURL, resources)
            let isSafe = isSafeToDelete(fileURL, fileType)

            results.append(LargeFileScanResult(
                id: UUID(),
                url: fileURL,
                sizeMB: Double(size) / 1024 / 1024,
                fileType: fileType,
                lastModified: try fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date(),
                isSafeToDelete: isSafe,
                warning: isSafe ? nil : generateWarning(fileURL, fileType)
            ))
        }
    }

    await MainActor.run {
        self.results = results.sorted { $0.sizeMB > $1.sizeMB }
        self.totalSizeFoundMB = results.reduce(0) { $0 + $1.sizeMB }
    }
}
```

**New View: `LargeFileFinderView.swift`**
```swift
struct LargeFileFinderView: View {
    @StateObject private var finder = LargeFileFinder.shared
    @State private var selectedFiles: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack {
            // Scan controls
            HStack {
                Button(finder.isScanning ? "Scanning..." : "Scan Now") {
                    Task { await finder.scan(locations: .defaultLocations) }
                }
                .disabled(finder.isScanning)

                TextField("Minimum size (MB)", value: $finder.minimumSizeThresholdMB, format: .number)
            }

            // Results summary
            Text("Found \(finder.results.count) files (\(finder.totalSizeFoundMB, .size)MB)")

            // File list with selection
            List(finder.results, selection: $selectedFiles) { file in
                FileRow(file: file)
                    .opacity(file.isSafeToDelete ? 1.0 : 0.7)
            }

            // Delete button
            Button("Delete Selected (\(selectedFiles.count))") {
                showDeleteConfirmation = true
            }
            .disabled(selectedFiles.isEmpty)
            .buttonStyle(.borderedProminent)
        }
    }
}
```

### Files to Create/Modify

| File | Action | Risk |
|------|--------|------|
| `Models/LargeFileScanResult.swift` | CREATE | LOW |
| `Services/LargeFileFinder.swift` | CREATE | MEDIUM |
| `Views/LargeFileFinderView.swift` | CREATE | LOW |
| `Views/SettingsView.swift` | MODIFY (add tab) | LOW |
| `ComprehensiveOptimizer.swift` | MODIFY (integration) | LOW |

### Safety Considerations

1. **Protected paths** — Never scan/delete from:
   - `/System`, `/Library`, `/Applications`
   - `~/Library/Application Support`
   - Any path in whitelist

2. **File type warnings** — Warn before deleting:
   - `.app` bundles ("This will uninstall an application")
   - `.dmg` in unexpected locations
   - Files modified in last 24 hours

3. **Trash vs Delete** — Default to move to trash, offer permanent delete as option

### Success Criteria

- [ ] Scans selected locations efficiently
- [ ] Correctly identifies file types
- [ ] Shows clear warnings for unsafe deletions
- [ ] Moves files to trash (reversible)
- [ ] Respects whitelist
- [ ] Progress indicator during scan

---

## Feature 3: Privacy Permissions Audit

### Objective

Give users visibility into app permissions with:
- List of apps with Full Disk Access
- List of apps with Accessibility access
- List of apps with Automation permissions
- TCC (Transparency, Consent, and Control) database viewer
- One-click review in System Settings

### Technical Approach

**TCC Database Access**

macOS stores permissions in a SQLite database at:
`/Library/Application Support/com.apple.TCC/TCC.db`

⚠️ **Requires Full Disk Access** for Pulse to read

**New Service: `PermissionsAuditService`**
```swift
class PermissionsAuditService: ObservableObject {
    static let shared = PermissionsAuditService()

    @Published var fullDiskAccessApps: [AppPermission] = []
    @Published var accessibilityApps: [AppPermission] = []
    @Published var automationApps: [AppPermission] = []
    @Published var hasFullDiskAccess = false

    struct AppPermission: Identifiable {
        let id: UUID
        let bundleID: String
        let appName: String
        let path: URL
        let grantedDate: Date
        let permissionType: PermissionType
    }

    enum PermissionType {
        case fullDiskAccess
        case accessibility
        case automation
        case camera
        case microphone
        case screenRecording
    }

    func refresh() async
    func openSystemSettings()
    func requestFullDiskAccess()
}
```

**Read TCC Database**
```swift
func refresh() async {
    // Check if we have Full Disk Access
    let tccPath = URL(filePath: "/Library/Application Support/com.apple.TCC/TCC.db")
    hasFullDiskAccess = FileManager.default.isReadableFile(atPath: tccPath.path)

    guard hasFullDiskAccess else {
        // Can't read TCC - show instructions
        return
    }

    // Read TCC database
    let db = try? Database(path: tccPath.path)

    // Query for Full Disk Access
    letFDAApps = try? db?.query("""
        SELECT client, last_modified
        FROM access
        WHERE service = 'SystemPolicyAllFiles' AND allowed = 1
    """)

    // Query for Accessibility
    let accessibilityApps = try? db?.query("""
        SELECT client, last_modified
        FROM access
        WHERE service = 'Accessibility' AND allowed = 1
    """)

    // Query for Automation
    let automationApps = try? db?.query("""
        SELECT client, last_modified
        FROM access
        WHERE service = 'AppleEvents' AND allowed = 1
    """)

    await MainActor.run {
        self.fullDiskAccessApps = mapToAppPermission(fdaApps, type: .fullDiskAccess)
        self.accessibilityApps = mapToAppPermission(accessibilityApps, type: .accessibility)
        self.automationApps = mapToAppPermission(automationApps, type: .automation)
    }
}
```

**New View: `PrivacyAuditView.swift`**
```swift
struct PrivacyAuditView: View {
    @StateObject private var service = PermissionsAuditService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // FDA status banner
            if !service.hasFullDiskAccess {
                WarningBanner(
                    title: "Full Disk Access Required",
                    message: "Grant Full Disk Access to see all permissions",
                    action: { service.requestFullDiskAccess() }
                )
            }

            // Permission sections
            PermissionSection(
                title: "Full Disk Access",
                icon: "folder.badge.gearshape",
                apps: service.fullDiskAccessApps
            )

            PermissionSection(
                title: "Accessibility",
                icon: "universalaccess.circle",
                apps: service.accessibilityApps
            )

            PermissionSection(
                title: "Automation",
                icon: "applescript",
                apps: service.automationApps
            )

            // Open System Settings
            Button("Open Privacy & Security Settings") {
                service.openSystemSettings()
            }
        }
    }
}
```

### Files to Create/Modify

| File | Action | Risk |
|------|--------|------|
| `Models/AppPermission.swift` | CREATE | LOW |
| `Services/PermissionsAuditService.swift` | CREATE | MEDIUM |
| `Views/PrivacyAuditView.swift` | CREATE | LOW |
| `Views/SecurityView.swift` | MODIFY (add section) | LOW |

### TCC Access Notes

- Reading TCC.db **requires Full Disk Access**
- Without FDA, show graceful fallback with System Settings link
- Consider requesting FDA during onboarding flow

### Success Criteria

- [ ] Shows accurate list of apps with permissions
- [ ] Graceful handling when FDA not granted
- [ ] One-click link to System Settings
- [ ] Clear icons and organization
- [ ] No crashes on macOS version differences

---

## Feature 4: Menu Bar Quick Actions

### Objective

Provide one-click cleanup actions directly from the menu bar:

- "Quick Cleanup" — Clear caches without confirmation
- "Stop Memory Hog" — Kill top memory process
- "Open Pulse" — Show main window

### Technical Approach

**Update `MenuBarLiteView.swift`**
```swift
struct MenuBarLiteView: View {
    @StateObject private var manager = MemoryMonitorManager.shared
    @StateObject private var optimizer = ComprehensiveOptimizer.shared
    @State private var isRunningCleanup = false
    @State private var cleanupResult: String?

    var body: some View {
        VStack {
            // Current memory status
            HStack {
                Text("Memory: \(manager.memoryUsagePercent, specifier: "%.0f")%")
                Spacer()
                Text("\(manager.memoryUsedGB, specifier: "%.1f") / \(manager.memoryTotalGB, specifier: "%.1f") GB")
            }

            Divider()

            // Quick Actions
            Button {
                Task { await runQuickCleanup() }
            } label: {
                Label("Quick Cleanup", systemImage: "bolt.circle")
                if isRunningCleanup {
                    ProgressView()
                }
            }
            .disabled(isRunningCleanup)

            Button {
                stopMemoryHog()
            } label: {
                Label("Stop Memory Hog", systemImage: "stop.circle")
            }

            Divider()

            Button {
                manager.showMainWindow()
            } label: {
                Label("Open Pulse", systemImage: "window.desktop")
            }

            Button("Quit Pulse") {
                NSApp.terminate(nil)
            }
        }
        .padding()
    }

    func runQuickCleanup() async {
        isRunningCleanup = true

        // Run cleanup without confirmation (small items only)
        let result = await optimizer.quickCleanup(maxSizeMB: 500)

        cleanupResult = "Freed \(result.freedMB, specifier: "%.0f") MB"
        isRunningCleanup = false

        // Auto-hide after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        NSApp.keyWindow?.orderOut(nil)
    }

    func stopMemoryHog() {
        let topProcess = ProcessMemoryMonitor.shared.topProcesses.first
        guard let process = topProcess else { return }

        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "Stop \(process.name)?"
        alert.informativeText = "This process is using \(process.memoryMB, specifier: "%.0f") MB of memory"
        alert.addButton(withTitle: "Stop")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSRunningApplication(process.pid)?.terminate()
        }
    }
}
```

### Files to Modify

| File | Action | Risk |
|------|--------|------|
| `Views/MenuBarLiteView.swift` | MODIFY | MEDIUM |
| `ComprehensiveOptimizer.swift` | MODIFY (add quickCleanup) | LOW |

### Success Criteria

- [ ] Quick cleanup runs in <5 seconds
- [ ] Confirmation for stopping processes
- [ ] Menu bar popover auto-hides after action
- [ ] Visual feedback during cleanup
- [ ] No crashes or hangs

---

## Implementation Timeline

### Week 1: Trigger History UI
- Day 1-2: Create models and HistoricalMetricsService
- Day 3: Integrate with SmartTriggerMonitor
- Day 4-5: Build TriggerHistoryView
- Day 6: Add persistence (JSON file)
- Day 7: Testing and polish

### Week 2: Large File Finder
- Day 1-2: Create LargeFileFinder service
- Day 3: Implement file type detection
- Day 4-5: Build LargeFileFinderView
- Day 6: Add safety checks and whitelist
- Day 7: Testing and QA

### Week 3: Privacy Permissions Audit
- Day 1-2: Create PermissionsAuditService
- Day 3: TCC database reader
- Day 4-5: Build PrivacyAuditView
- Day 6: FDA request flow
- Day 7: Testing across macOS versions

### Week 4: Menu Bar Quick Actions + Polish
- Day 1-2: Update MenuBarLiteView
- Day 3: Add quickCleanup to ComprehensiveOptimizer
- Day 4-5: Full regression testing
- Day 6: Documentation
- Day 7: Phase 3 complete!

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| TCC database format changes | LOW | MEDIUM | Graceful fallback, version detection |
| Large file scan performance | MEDIUM | LOW | Progress indicators, cancellable |
| Accidental file deletion | LOW | HIGH | Trash-first approach, confirmations |
| Menu bar crashes | LOW | HIGH | Extensive testing, error handling |
| Full Disk Access not granted | MEDIUM | LOW | Graceful degradation |

---

## Verification Profile: ui-surface

**Gates in order:**
1. `swiftlint` — lint all new code
2. `swift build` — build passes
3. `swift test` — all tests pass (target: 150+ tests)
4. Manual QA — UI verification for all 4 features

---

## Rollback Plan

**Type:** discard-working-tree | drop-branch

**Scope:** All Phase 3 changes

**Action:**
```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse
git checkout -- .
# OR if worktree:
ExitWorktree(action: "remove")
```

**Verify:**
```bash
swift build  # Should succeed
swift test   # Should pass (118 tests from Phase 2)
```

---

## Success Criteria for Phase 3

Phase 3 is complete when:

- [ ] All 4 features implemented and functional
- [ ] 30+ new tests added (total: 150+ tests)
- [ ] All tests pass (95%+ pass rate)
- [ ] Build passes
- [ ] No regressions in Phase 1/2 features
- [ ] Manual QA complete for all features
- [ ] Documentation updated

---

## Out of Scope (Future Phases)

- Real-time threat monitoring (requires Endpoint Security framework)
- Menu bar widgets (macOS Sonoma+ only)
- iCloud sync for settings/history
- Weekly email reports
- Browser extension for download cleanup

---

*Created: March 31, 2026*
*Phase 3 Planning Complete*
*Ready for /implement*
