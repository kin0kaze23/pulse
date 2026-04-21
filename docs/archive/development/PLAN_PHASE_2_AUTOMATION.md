# Phase 2: Automation

**Date:** 2026-03-30
**Lane:** STANDARD
**Risk Score:** 5/10
**Verification Profile:** logic-backend (lint + typecheck + targeted tests)

---

## Objective

Implement automation features so Pulse can "set and forget" run in the background:

1. **AutomationScheduler** — Daily/weekly scheduled cleanup and security scans
2. **SmartTriggerMonitor** — Automatic optimization on battery, memory, thermal thresholds
3. **QuietHoursManager** — Suppress non-critical notifications during user-specified hours
4. **Auto-cleanup Mode** — Skip confirmation for small cleanups (< 500MB)

---

## Touch List

| File | Action | Risk |
|------|--------|------|
| `MemoryMonitor/Sources/Services/AutomationScheduler.swift` | NEW — Scheduled jobs | Medium (new service) |
| `MemoryMonitor/Sources/Services/SmartTriggerMonitor.swift` | NEW — Trigger detection | Medium (new service) |
| `MemoryMonitor/Sources/Services/QuietHoursManager.swift` | NEW — Quiet hours logic | Low (simple logic) |
| `MemoryMonitor/Sources/Services/MemoryMonitorManager.swift` | Integrate automation | Medium (coordinator) |
| `MemoryMonitor/Sources/Views/SettingsView.swift` | Add automation settings UI | Low (UI only) |
| `MemoryMonitor/Sources/Models/AppSettings.swift` | Add automation preferences | Low (model) |
| `Tests/AutomationSchedulerTests.swift` | NEW — Scheduler tests | Low (tests) |
| `Tests/SmartTriggerMonitorTests.swift` | NEW — Trigger tests | Low (tests) |
| `Tests/QuietHoursManagerTests.swift` | NEW — Quiet hours tests | Low (tests) |

**Total:** 9 files (8 new, 2 modified)

---

## Success Criteria

### AutomationScheduler
- [ ] User can enable/disable daily cleanup
- [ ] User can set daily cleanup time (HH:MM picker)
- [ ] User can enable/disable weekly security scan
- [ ] User can select day of week for weekly scan
- [ ] Scheduled jobs persist across app restarts (UserDefaults)
- [ ] Jobs execute at scheduled time (within 60s accuracy)
- [ ] Jobs run even when app is in background (tested)

### SmartTriggerMonitor
- [ ] Battery trigger fires when battery < threshold (default 30%)
- [ ] Memory trigger fires when memory pressure > threshold (default 80%)
- [ ] Thermal trigger fires when thermal state = serious/critical
- [ ] Debounce prevents repeated triggers (5min cooldown)
- [ ] Each trigger has independent enable/disable toggle
- [ ] Triggers logged to history for user review

### QuietHoursManager
- [ ] User can enable/disable quiet hours
- [ ] User can set start time (HH:MM)
- [ ] User can set end time (HH:MM)
- [ ] Notifications suppressed during quiet hours
- [ ] Critical alerts still fire (configurable override)
- [ ] Visual indicator shows "Quiet Hours Active" in UI

### Auto-cleanup Mode
- [ ] User can enable auto-cleanup for small jobs
- [ ] Threshold configurable (default < 500MB)
- [ ] Confirmation still shown for large cleanups
- [ ] Works with both manual and scheduled cleanups

### General
- [ ] All automation features persist across restarts
- [ ] Build passes (`swift build`)
- [ ] Tests pass (existing 80 + new ~30 tests = ~110 total)
- [ ] No regressions in Phase 1 features

---

## Implementation Notes

### 1. AutomationScheduler

**Architecture:**
```swift
class AutomationScheduler: ObservableObject {
    // Settings (persisted to UserDefaults)
    @Published var dailyCleanupEnabled: Bool
    @Published var dailyCleanupTime: String // "03:00"
    @Published var weeklySecurityScanEnabled: Bool
    @Published var weeklySecurityScanDay: Int // 1-7 (Sunday = 1)

    // Internal state
    private var timers: [String: DispatchSourceTimer]
    private let workQueue = DispatchQueue(label: "com.pulse.automation", qos: .utility)

    // Scheduling
    func scheduleDailyCleanup(at time: String)
    func scheduleWeeklySecurity(on day: Int)
    func cancelAllScheduledJobs()

    // Execution
    private func runScheduledCleanup()
    private func runScheduledSecurityScan()
}
```

**Implementation approach:**
- Use `DispatchSourceTimer` for scheduling (more reliable than `Timer`)
- Calculate next fire time based on current time + target time
- Persist settings to `UserDefaults` with keys:
  - `automation.dailyCleanupEnabled`
  - `automation.dailyCleanupTime`
  - `automation.weeklySecurityEnabled`
  - `automation.weeklySecurityDay`

**Key challenge:** Handling app background execution
- macOS allows background execution for menu bar apps
- Timer continues firing when window is closed
- Test with app minimized to menu bar only

---

### 2. SmartTriggerMonitor

**Architecture:**
```swift
class SmartTriggerMonitor: ObservableObject {
    // Battery trigger
    @Published var batteryTriggerEnabled: Bool = true
    @Published var batteryThreshold: Double = 30.0 // percent

    // Memory trigger
    @Published var memoryTriggerEnabled: Bool = true
    @Published var memoryThreshold: Double = 80.0 // percent

    // Thermal trigger (always on when enabled)
    @Published var thermalTriggerEnabled: Bool = true

    // Internal state
    private var lastTriggerTime: [String: Date] = [:]
    private let triggerCooldown: TimeInterval = 300 // 5 minutes

    // Monitors (references to existing services)
    private let healthMonitor = SystemHealthMonitor.shared
    private let systemMonitor = SystemMemoryMonitor.shared
    private let optimizer = MemoryOptimizer.shared

    // Check triggers (called every 30s by MemoryMonitorManager)
    func checkTriggers()

    // Fire trigger with debounce
    private func fireTrigger(type: String, action: () -> Void)
}
```

**Trigger logic:**

| Trigger | Condition | Action |
|---------|-----------|--------|
| Battery | `batteryPercentage < threshold` AND `!isCharging` | Run gentle cleanup (caches only) |
| Memory | `memoryUsedPercent > threshold` | Free RAM + close idle apps |
| Thermal | `thermalState == .serious || .critical` | Aggressive cleanup + notify user |

**Debounce logic:**
```swift
private func fireTrigger(type: String, action: () -> Void) {
    guard Date().timeIntervalSince(lastTriggerTime[type, default: .distantPast]) > triggerCooldown else {
        return // Cooldown active
    }
    lastTriggerTime[type] = Date()
    action()
}
```

---

### 3. QuietHoursManager

**Architecture:**
```swift
class QuietHoursManager: ObservableObject {
    @Published var quietHoursEnabled: Bool = false
    @Published var quietHoursStart: String = "22:00" // 10 PM
    @Published var quietHoursEnd: String = "08:00"   // 8 AM
    @Published var allowCriticalAlerts: Bool = true

    private var timer: DispatchSourceTimer?

    func startMonitoring()
    func stopMonitoring()
    func isQuietHours() -> Bool
    func shouldSuppressNotification() -> Bool
}
```

**Quiet hours detection:**
```swift
func isQuietHours() -> Bool {
    guard quietHoursEnabled else { return false }

    let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
    let start = parseTime(quietHoursStart)
    let end = parseTime(quietHoursEnd)

    // Handle overnight ranges (e.g., 22:00 - 08:00)
    if start.hour > end.hour || (start.hour == end.hour && start.minute > end.minute) {
        // Overnight: before end OR after start
        return now >= start || now <= end
    } else {
        // Same day: between start and end
        return now >= start && now <= end
    }
}
```

**Integration with AlertManager:**
```swift
// In AlertManager.fireAlert()
if QuietHoursManager.shared.shouldSuppressNotification() {
    // Log alert but don't show notification
    activeAlerts.insert(notification, at: 0)
    return // Skip UNUserNotificationCenter
}
```

---

### 4. Auto-cleanup Mode

**AppSettings additions:**
```swift
@Published var autoCleanupEnabled: Bool = false
@Published var autoCleanupThresholdMB: Double = 500.0
```

**MemoryOptimizer modification:**
```swift
func freeRAM() {
    guard !isWorking else { return }

    comprehensive.scanForCleanup()

    // Wait for scan completion...

    if comprehensive.needsConfirmation == true,
       let plan = comprehensive.currentPlan {
        // NEW: Auto-cleanup mode check
        if AppSettings.shared.autoCleanupEnabled &&
           plan.totalSizeMB < AppSettings.shared.autoCleanupThresholdMB {
            // Skip confirmation, execute directly
            executeCleanup()
            return
        }

        // Show confirmation dialog (existing behavior)
        showCleanupConfirmation = true
    }
}
```

---

## Settings UI Design

**New section in SettingsView:**

```
┌─────────────────────────────────────────────────────────┐
│  AUTOMATION                                             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Scheduled Cleanup                                      │
│  [ ] Enable daily cleanup                               │
│  Time: [03:00 ▼]                                        │
│                                                         │
│  [ ] Enable weekly security scan                        │
│  Day: [Sunday ▼]                                        │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Smart Triggers                                         │
│  [✓] Battery trigger (fire when < [30 ▼]%)             │
│  [✓] Memory trigger (fire when > [80 ▼]%)              │
│  [✓] Thermal trigger (fire when serious/critical)      │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Quiet Hours                                            │
│  [ ] Enable quiet hours                                 │
│  From: [22:00 ▼]  To: [08:00 ▼]                        │
│  [✓] Allow critical alerts during quiet hours          │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Auto-cleanup                                           │
│  [ ] Skip confirmation for small cleanups (< [500 ▼]MB)│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Rollback Plan

**Type:** discard-working-tree

**Scope:** All Phase 2 files

**Action:**
```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse

# Delete new files
rm MemoryMonitor/Sources/Services/AutomationScheduler.swift
rm MemoryMonitor/Sources/Services/SmartTriggerMonitor.swift
rm MemoryMonitor/Sources/Services/QuietHoursManager.swift
rm Tests/AutomationSchedulerTests.swift
rm Tests/SmartTriggerMonitorTests.swift
rm Tests/QuietHoursManagerTests.swift

# Revert modified files
git checkout -- MemoryMonitor/Sources/Services/MemoryMonitorManager.swift
git checkout -- MemoryMonitor/Sources/Views/SettingsView.swift
git checkout -- MemoryMonitor/Sources/Models/AppSettings.swift
```

**Verify:**
```bash
swift build  # Should succeed
swift test   # Should pass (80 tests)
```

---

## Autonomy Budget

| Budget | Limit | Notes |
|--------|-------|-------|
| Max files | 9 | Touch list = 9 files |
| Max commands | 20 | swift build, swift test, etc. |
| Max retries | 3 | Per gate |
| Expansions | 1 | With user approval if needed |

---

## Verification Profile: logic-backend

**Gates in order:**
1. `swift build` — build (no errors)
2. `swift test` — all tests pass (existing + new)
3. Manual QA — verify automation features work

**Test coverage requirements:**
- AutomationScheduler: test scheduling, persistence, execution
- SmartTriggerMonitor: test each trigger, debounce logic
- QuietHoursManager: test isQuietHours() for various time ranges
- Integration: test end-to-end automation flow

---

## Risk Factors

| Factor | Score | Notes |
|--------|-------|-------|
| Domain sensitivity | 0 | No auth/payment/schema changes |
| Blast radius | 2 | New services + coordinator modifications |
| State impact | 1 | Destructive actions require confirmation |
| External dependency | 0 | No new external dependencies |
| Rollback difficulty | 1 | Simple git checkout + file delete |
| Ambiguity | 1 | Clear implementation notes |
| **Total** | **5/10** | STANDARD lane |

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| `SystemHealthMonitor` | ✅ Existing | Battery, thermal data |
| `SystemMemoryMonitor` | ✅ Existing | Memory pressure data |
| `MemoryOptimizer` | ✅ Existing | Cleanup execution |
| `AlertManager` | ✅ Existing | Notification integration |
| `UserDefaults` | ✅ Built-in | Settings persistence |
| `DispatchSourceTimer` | ✅ Built-in | Reliable scheduling |

---

## Out of Scope

- Background execution for sandboxed App Store apps (not applicable — Pulse is local)
- iCloud sync of automation settings (future Phase 3+)
- Advanced scheduling (multiple jobs per day, custom intervals)
- Trigger history UI (data logged, but UI deferred to Phase 3)
- Machine learning for smart suggestions (Phase 4)

---

## Task Breakdown

### Task 1: AppSettings additions
- Add automation preferences to AppSettings model
- UserDefaults keys for persistence

### Task 2: AutomationScheduler implementation
- Core scheduling logic with DispatchSourceTimer
- Daily cleanup job
- Weekly security scan job
- Persistence to UserDefaults

### Task 3: SmartTriggerMonitor implementation
- Battery trigger with threshold
- Memory trigger with threshold
- Thermal trigger
- Debounce logic

### Task 4: QuietHoursManager implementation
- Time range parsing
- isQuietHours() logic
- shouldSuppressNotification() logic
- Timer-based monitoring

### Task 5: MemoryMonitorManager integration
- Wire in AutomationScheduler
- Wire in SmartTriggerMonitor (check triggers every 30s)
- Wire in QuietHoursManager

### Task 6: SettingsView UI
- Automation section
- Scheduled cleanup settings
- Smart trigger settings
- Quiet hours settings
- Auto-cleanup settings

### Task 7: Unit Tests
- AutomationSchedulerTests
- SmartTriggerMonitorTests
- QuietHoursManagerTests

### Task 8: Integration Testing
- End-to-end automation flow
- Verify persistence across restarts
- Verify background execution

---

## Implementation Order

```
1. AppSettings (foundation)
   ↓
2. AutomationScheduler (depends on AppSettings)
   ↓
3. SmartTriggerMonitor (depends on existing monitors)
   ↓
4. QuietHoursManager (standalone)
   ↓
5. MemoryMonitorManager integration (depends on 2, 3, 4)
   ↓
6. SettingsView UI (depends on 2, 3, 4)
   ↓
7. Unit Tests (depends on 2, 3, 4)
   ↓
8. Integration Testing (depends on all)
```

---

## Estimated Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Planning | Complete | This document |
| Implementation | 5-7 days | All 8 tasks |
| Testing | 2 days | Unit + integration tests |
| Polish | 1 day | Bug fixes, UI refinement |
| **Total** | **~2 weeks** | Phase 2 complete |

---

## Next Steps

1. Review and approve this plan
2. Create PLAN.md in Pulse repo root
3. Begin Task 1: AppSettings additions
4. Checkpoint after each task
5. Run /gates after all tasks complete
6. Update NOW.md with Phase 2 completion summary

---

*Plan created: March 30, 2026*
*Phase 2: Automation*
*Lane: STANDARD | Risk: 5/10*
