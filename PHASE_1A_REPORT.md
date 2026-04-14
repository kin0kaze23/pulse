# Phase 1a Report: AppSettings Dependency Boundary Audit

Date: 2026-04-14

## Purpose

Inventory every AppSettings dependency across the codebase, classify each as
PulseCore input / App-UI preference / monitor-only runtime state, and define
the extraction boundary for PulseCore.

## Dependency Inventory

### ComprehensiveOptimizer (3 AppSettings reads)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| cleanXcodeDerivedData | 693 | Gate: whether to scan DerivedData | **PulseCore input** |
| cleanXcodeDeviceSupport | 711 | Gate: whether to scan DeviceSupport | **PulseCore input** |
| whitelistedPaths | 1569 | User-defined path whitelist for cleanup | **PulseCore input** |

Notes: All 3 are cleanup-relevant settings. These are exactly the kind of
inputs PulseCore should receive as parameters, not read from a singleton.

### MemoryMonitorManager (11 AppSettings reads, 3 Combine subscriptions)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| liteMode | 39, 81 | Initialize + reactive toggle | **App/UI preference** |
| refreshInterval | 66, 105 | Reactive + read for monitor intervals | **App/UI preference** |
| topProcessesCount | 111, 114, 216 | Process list size | **App/UI preference** |
| diskSpaceGuardianEnabled | 141 | Gate disk monitoring | **App/UI preference** |
| autoKillEnabled | 75, 179 | Reactive + set on AutoKillManager | **App/UI preference** |
| autoKillMemoryGB | 180 | Threshold for auto-kill | **App/UI preference** |
| autoKillCPUPercent | 181 | Threshold for auto-kill | **App/UI preference** |
| autoKillWarningFirst | 182 | Behavior flag | **App/UI preference** |
| menuBarDisplayMode | 316 | Menu bar text format | **App/UI preference** |

Notes: ALL of MemoryMonitorManager's AppSettings usage is App/UI preference.
None of these belong in PulseCore. The MemoryMonitorManager is a coordinator
for the monitoring subsystem -- it stays in PulseApp.

### DiskSpaceGuardian (5 AppSettings reads)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| diskWarningThresholdGB | 20 | Threshold for warning | **App/UI preference** |
| diskCriticalThresholdGB | 24 | Threshold for critical alert | **App/UI preference** |
| autoCleanupOnCriticalDisk | 28 | Gate auto-cleanup | **App/UI preference** |
| autoCleanupThresholdGB | 32 | Threshold for auto-cleanup | **App/UI preference** |
| hasSeenPermissionOnboarding | 61 | Guard: don't start if not onboarded | **App/UI preference** |

Notes: DiskSpaceGuardian stays in PulseApp. The autoCleanupThresholdGB is
interesting -- it controls when to trigger cleanup. In the PulseCore model,
this would be handled by the CLI/App deciding WHEN to call PulseCore, not
by PulseCore itself.

### AutoKillManager (0 AppSettings reads)

Classified directly in MemoryMonitorManager (lines 179-182). Stays in PulseApp.

### AlertManager (6 AppSettings reads)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| notificationsEnabled | 53, 207, 235 | Gate notifications | **App/UI preference** |
| alertThresholds | 55 | Threshold list | **App/UI preference** |
| alertCooldownMinutes | 61 | Cooldown between alerts | **App/UI preference** |
| diskSpaceGuardianEnabled | 236 | Gate disk alerts | **App/UI preference** |
| diskWarningThresholdGB | 238 | Alert threshold | **App/UI preference** |
| diskCriticalThresholdGB | 239 | Alert threshold | **App/UI preference** |

Notes: AlertManager stays in PulseApp. Pure notification logic.

### QuietHoursManager (4 AppSettings reads + 4 subscriptions + 4 writes)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| quietHoursEnabled | 27, 39, 86 | Read, subscribe, write | **App/UI preference** |
| quietHoursStart | 28, 49, 97 | Read, subscribe, write | **App/UI preference** |
| quietHoursEnd | 29, 59, 108 | Read, subscribe, write | **App/UI preference** |
| allowCriticalAlerts | 30, 69, 119 | Read, subscribe, write | **App/UI preference** |

Notes: Pure App/UI preference. Stays in PulseApp.

### SmartTriggerMonitor (5 AppSettings reads + 5 subscriptions + 5 writes + 2 cleanup checks)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| batteryTriggerEnabled | 39, 52, 109 | Read, subscribe, write | **App/UI preference** |
| batteryThreshold | 40, 62, 120 | Read, subscribe, write | **App/UI preference** |
| memoryTriggerEnabled | 41, 72, 131 | Read, subscribe, write | **App/UI preference** |
| memoryThreshold | 42, 82, 142 | Read, subscribe, write | **App/UI preference** |
| thermalTriggerEnabled | 43, 92, 153 | Read, subscribe, write | **App/UI preference** |
| autoCleanupEnabled | 264, 285 | Gate auto-cleanup in trigger | **App/UI preference** |
| autoCleanupThresholdMB | 264, 285 | Threshold for trigger-cleanup | **App/UI preference** |

Notes: All App/UI preference. Stays in PulseApp. The autoCleanupEnabled/
autoCleanupThresholdMB references in trigger handlers are the bridge between
monitoring and cleanup -- this is where PulseCore would be called.

### AutomationScheduler (4 AppSettings reads + 4 subscriptions + 4 writes + 2 cleanup checks)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| dailyCleanupEnabled | 30, 43, 94 | Read, subscribe, write | **App/UI preference** |
| dailyCleanupTime | 31, 54, 105 | Read, subscribe, write | **App/UI preference** |
| weeklySecurityScanEnabled | 32, 65, 116 | Read, subscribe, write | **App/UI preference** |
| weeklySecurityScanDay | 33, 76, 127 | Read, subscribe, write | **App/UI preference** |
| autoCleanupEnabled | 269 | Gate scheduled cleanup | **App/UI preference** |
| autoCleanupThresholdMB | 269, 271 | Threshold | **App/UI preference** |

Notes: All App/UI preference. Stays in PulseApp.

### MemoryOptimizer (legacy, 3 AppSettings writes)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| totalFreedMB | 337 | Stats tracking | **App/UI preference** |
| totalCleanupCount | 338 | Stats tracking | **App/UI preference** |
| lastCleanupDate | 339 | Stats tracking | **App/UI preference** |
| cleanXcodeDerivedData | 578 | Gate cleanup | **PulseCore input** |

Notes: MemoryOptimizer is the legacy cleanup engine, superseded by
ComprehensiveOptimizer. Both reference cleanXcodeDerivedData.

### LargeFileFinder (1 AppSettings read)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| whitelistedPaths | 21 | User-defined path whitelist | **PulseCore input** |

### SystemMemoryMonitor (1 AppSettings read)

| Setting | Line | Usage | Classification |
|---|---|---|---|
| historyDurationMinutes | 103 | Trim history array | **App/UI preference** |

## Classification Summary

### PulseCore inputs (4 settings, 2 services)

These are the ONLY AppSettings that PulseCore needs:

1. cleanXcodeDerivedData (ComprehensiveOptimizer:693, MemoryOptimizer:578)
2. cleanXcodeDeviceSupport (ComprehensiveOptimizer:711)
3. whitelistedPaths (ComprehensiveOptimizer:1569, LargeFileFinder:21)

Plus future v0.2 settings: cleanDocker, cleanNpm, cleanHomebrew, etc.

### App/UI preferences (47+ settings, 8 services)

Everything else. All of these stay in PulseApp and are consumed by the
monitoring subsystem, not by cleanup logic.

### Monitor-only runtime state (0 settings)

No settings are purely for monitor runtime. All monitor-relevant settings
are App/UI preferences that control behavior thresholds.

## Proposed SettingsSnapshot for PulseCore

```swift
/// Configuration for a cleanup scan/apply operation.
/// This is the ONLY interface between PulseApp and PulseCore.
/// No ObservableObject, no @Published, no singleton, no UserDefaults.
struct CleanupConfig {
    /// Which profiles to include in the scan.
    var profiles: Set<CleanupProfile>

    /// User-defined paths to always skip during cleanup.
    var excludedPaths: [String]

    init(
        profiles: Set<CleanupProfile> = [.xcode, .homebrew],
        excludedPaths: [String] = []
    ) {
        self.profiles = profiles
        self.excludedPaths = excludedPaths
    }
}

enum CleanupProfile: String, CaseIterable {
    case xcode
    case homebrew
    // v0.2: case node, case docker, case browser, case system
}
```

How PulseApp creates this:

```swift
let config = CleanupConfig(
    profiles: settings.cleanXcodeDerivedData ? [.xcode] : [],
    excludedPaths: settings.whitelistedPaths
)
let plan = try pulseCore.scan(config: config)
```

## PulseCore Extraction Boundary (explicit)

PulseCore WILL contain:
- CleanupPlan, CleanupItem, CleanupWarning types
- CleanupResult type
- CleanupConfig type (above)
- SafetyValidator (protected paths, path validation)
- CleanupEngine (scanForCleanup, executeCleanup)
- DirectoryScanner (size estimation)
- TrashManager (deletion logic)
- CleanupProfile enum

PulseCore WILL NOT contain:
- @Published properties
- ObservableObject conformance
- AppSettings dependency
- Any AppKit/AppKit imports
- Any SwiftUI imports
- Any singleton pattern
- Any UserDefaults access
- Thread.sleep calls (UX timing, not business logic)
- Monitoring services (SystemMemoryMonitor, CPUMonitor, etc.)
- AutoKillManager
- AlertManager
- SecurityScanner
- SmartTriggerMonitor
- QuietHoursManager
- AutomationScheduler
- DiskSpaceGuardian

## Smallest First Extraction Slice

Phase 1 extraction should begin with one vertical slice:

1. CleanupProfile.xcode (DerivedData only, not DeviceSupport -- keep DeviceSupport for Phase 1 extension)
2. SafetyValidator (full protected paths, deny-list, home directory protection)
3. CleanupPlan (types)
4. CleanupEngine.scan(profile: .xcode, config: CleanupConfig) -> CleanupPlan
5. CleanupEngine.apply(plan: CleanupPlan) -> CleanupResult

This is enough to:
- Build PulseCore with zero UI coupling
- Build PulseCLI with `pulse clean --profile xcode --dry-run`
- Test end-to-end with temp directories

## Files to Touch First (Phase 1 proper)

1. Package.swift (add PulseCore target)
2. Sources/PulseCore/CleanupPlan.swift (new -- types)
3. Sources/PulseCore/CleanupConfig.swift (new -- config struct)
4. Sources/PulseCore/SafetyValidator.swift (new -- copy + decouple from AppSettings)
5. Sources/PulseCore/DirectoryScanner.swift (new -- copy size estimation)
6. Sources/PulseCore/CleanupEngine.swift (new -- extract scan/apply from ComprehensiveOptimizer)
7. MemoryMonitor/Sources/Services/ComprehensiveOptimizer.swift (modify -- become thin adapter)
8. MemoryMonitor/Sources/Services/StorageAnalyzer.swift (modify -- delegate to PulseCore)

## Risks

1. ComprehensiveOptimizer is 1,648 lines. The extraction will reveal coupling
   that is not visible from the outside. Mitigation: extract one method at
   a time, keep adapter pattern until PulseCore is verified.

2. SettingsSnapshot design could be wrong. The 3 current PulseCore inputs
   (cleanXcodeDerivedData, cleanXcodeDeviceSupport, whitelistedPaths) are
   simple booleans and string arrays. The profile-based design proposed
   above is forward-compatible but may need adjustment during extraction.
   Mitigation: keep CleanupConfig simple for v0.1, add complexity later.

3. Thread.sleep calls in ComprehensiveOptimizer's scan methods (0.3s delays
   between phases for UX). These are not business logic. Mitigation: remove
   them from PulseCore; the CLI does not need fake delays.

4. AppSettings.shared is referenced from 30+ locations. After PulseCore
   extraction, the remaining references are all in PulseApp and are fine.
   The critical cut is: ComprehensiveOptimizer must NOT read AppSettings
   directly; it receives CleanupConfig.

## Unresolved Questions

1. Should CleanupConfig be created by PulseApp (via adapter) or by the CLI
   directly? Both -- PulseApp creates it from AppSettings, CLI creates it
   from command-line arguments.

2. Should the legacy MemoryOptimizer be deleted during extraction or kept
   alongside until PulseApp is fully migrated? Keep alongside until Phase 3.

## Go/No-Go for Phase 1 (full extraction)

**GO** -- conditional on:
- Starting with the Xcode-only slice (DerivedData + safety + result model)
- Keeping ComprehensiveOptimizer as a thin adapter during extraction
- Removing Thread.sleep calls from PulseCore
- Not extracting monitoring services, security scanner, or automation

The dependency audit confirms that only 3-4 AppSettings properties are
needed by PulseCore. The boundary is clean and achievable.
