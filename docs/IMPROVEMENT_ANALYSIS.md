# Pulse Improvement Analysis

> Generated: 2026-03-22 | Based on codebase analysis + open source research

---

## Executive Summary

Pulse is already a solid macOS menu bar app with:
- ✅ Real-time memory/CPU/disk/network monitoring
- ✅ Basic security scanner (LaunchAgents, keyloggers)
- ✅ Developer profiles engine
- ✅ Smart suggestions
- ✅ Auto-kill for runaway processes

**This document outlines opportunities to make Pulse exceptional.**

---

## 1. UI/UX Improvements

### 1.1 Missing Features from Design Spec

| Feature | Status | Priority |
|---------|--------|----------|
| Health Score Gauge (A-F letter grade) | ⚠️ Partial | High |
| Line charts for memory/CPU history | ❌ Missing | High |
| Network speed line chart | ❌ Missing | Medium |
| Process table with kill buttons | ✅ Done | - |
| Menu bar popover redesign | ⚠️ Basic | Medium |
| Temperature monitoring | ❌ Missing | High |
| Fan speed monitoring | ❌ Missing | Medium |
| Dark mode specific refinements | ⚠️ Partial | Low |

### 1.2 Recommended UI Enhancements

**A. Add Temperature & Fan Monitoring (High Impact)**
- Learn from **Stats** (exelban/stats) - MIT licensed
- Uses SMC (System Management Controller) via IOKit
- Show CPU/GPU temperature in Health view
- Add fan speed for Intel Macs
- Alert on thermal throttling

**B. Add Historical Charts (High Impact)**
- Use Swift Charts framework (already in SwiftUI)
- Memory % over time (last 30 min / 1 hour)
- CPU % over time
- Network throughput chart
- Store history in memory (circular buffer)

**C. Improve Health Score Visualization**
- Add letter grade (A/B/C/D/F) inside VitalityOrb
- Make the score feel more "Apple-like"
- Add trend indicator (↑ improving, ↓ declining)

**D. Menu Bar Popover Enhancement**
- Currently: basic stats
- Should be: Control Center style cards
- Add quick action buttons (Free Memory, Clean Caches)
- Show 1-2 critical suggestions

---

## 2. Security Engine Enhancements

### 2.1 Current vs Ideal

| Feature | Current | Ideal |
|---------|---------|-------|
| LaunchAgents scanning | ✅ | ✅ |
| LaunchDaemons scanning | ✅ | ✅ |
| Login Items | ✅ | ✅ |
| Keylogger detection | ✅ Basic | ✅ Enhanced |
| Browser extensions | ❌ | ✅ Needed |
| Cron jobs | ❌ | ✅ Needed |
| Kernel extensions | ❌ | ✅ Needed |
| Real-time monitoring | ⚠️ Basic | ✅ Endpoint Security |
| VirusTotal lookup | ❌ | ✅ Optional |
| Code signing verification | ❌ | ✅ Needed |

### 2.2 Learn from Objective-See

**From KnockKnock:**
```swift
// Scan 30+ persistence locations
let persistenceLocations = [
    "~/Library/LaunchAgents",
    "/Library/LaunchAgents", 
    "/Library/LaunchDaemons",
    "/Library/StartupItems",
    "~/Library/Application Support/com.apple.backgroundtaskmanagementagent",
    // Browser extensions
    "~/Library/Safari/Extensions",
    "~/Library/Application Support/Google/Chrome/Default/Extensions",
    // Cron jobs
    "/etc/crontab",
    "/usr/lib/cron/tabs",
    // Periodic scripts
    "/etc/periodic/daily",
    "/etc/periodic/weekly", 
    "/etc/periodic/monthly"
]
```

**From ReiKey:**
```swift
// Enhanced keylogger detection
// Listen for kCGNotifyEventTapAdded notification
NotificationCenter.default.addObserver(
    forName: NSNotification.Name("kCGNotifyEventTapAdded"),
    object: nil,
    queue: nil
) { notification in
    // New event tap detected - check if it's a keylogger
}
```

**From BlockBlock (Real-time):**
- Requires **Endpoint Security Framework**
- Needs System Extension entitlement
- User must approve in System Settings
- Real-time file monitoring for persistence locations

### 2.3 Recommended Security Upgrades

**Phase 1 (Easy - No entitlements required):**
- [ ] Add browser extension scanning (Safari, Chrome, Firefox)
- [ ] Add cron job scanning
- [ ] Add kernel extension checking (`/Library/Extensions`)
- [ ] Add code signing verification for each persistence item
- [ ] Add "signed by Apple" vs "signed by developer" vs "unsigned" badges

**Phase 2 (Requires System Extension):**
- [ ] Implement Endpoint Security for real-time monitoring
- [ ] Alert when new LaunchAgent is created
- [ ] Alert when new Login Item is added
- [ ] Requires Apple Developer account + notarization

**Phase 3 (Optional):**
- [ ] VirusTotal hash lookup API integration
- [ ] YARA rule scanning for known malware patterns

---

## 3. Optimization Engine Improvements

### 3.1 Current Cache Categories

| Category | Status | Notes |
|----------|--------|-------|
| Xcode DerivedData | ✅ | Cleanable |
| Xcode Archives | ✅ | Cleanable |
| iOS Simulators | ✅ | Cleanable |
| node_modules | ✅ | Detected, not cleaned |
| Homebrew cache | ✅ | Cleanable |
| Docker images | ✅ | Cleanable |
| Trash | ✅ | Cleanable |
| Browser caches | ⚠️ Basic | Safari/Chrome |
| npm/yarn cache | ❌ | Missing |
| pip cache | ❌ | Missing |
| Go modules cache | ❌ | Missing |
| Adobe cache | ❌ | Missing |
| Spotify cache | ❌ | Missing |
| Teams cache | ❌ | Missing |

### 3.2 Learn from mac-cleanup (MIT)

**Add these cleaning categories:**

```swift
// Package Manager Caches
let additionalCaches = [
    // npm
    "~/.npm/_cacache",
    // Yarn
    "~/Library/Caches/Yarn",
    // pip
    "~/Library/Caches/pip",
    // Go modules
    "~/go/pkg/mod/cache",
    // CocoaPods
    "~/Library/Caches/CocoaPods",
    // Composer
    "~/.composer/cache",
    // Maven
    "~/.m2/repository",
    
    // Application Caches
    // Adobe
    "~/Library/Application Support/Adobe/CameraRaw/Cache",
    // Spotify
    "~/Library/Caches/com.spotify.client",
    // Teams
    "~/Library/Application Support/Microsoft/Teams/Cache",
    // Slack
    "~/Library/Application Support/Slack/Cache",
    // Discord
    "~/Library/Application Support/discord/Cache",
    // Steam
    "~/Library/Application Support/Steam/depotcache",
    // Minecraft
    "~/Library/Application Support/minecraft/logs",
    
    // System
    // User logs
    "~/Library/Logs",
    // System logs (requires sudo)
    "/var/log",
]
```

### 3.3 Recommended Optimization Upgrades

- [ ] Add "Package Manager Caches" category (npm, yarn, pip, go, cocoapods)
- [ ] Add "Chat Apps Caches" category (Slack, Teams, Discord)
- [ ] Add "Media Apps Caches" category (Spotify, Steam)
- [ ] Add "Adobe Caches" category (Lightroom, Premiere)
- [ ] Show estimated savings before cleaning
- [ ] Add "Scheduled Cleanup" feature (daily/weekly)
- [ ] Add "Cleanup History" to show what was cleaned

---

## 4. Disk Cleanup Module Upgrade

### 4.1 Current Storage Analyzer

The `StorageAnalyzer` already scans:
- ✅ iOS Updates
- ✅ iOS Backups
- ✅ node_modules
- ✅ Time Machine snapshots
- ✅ Large files
- ✅ Downloads

### 4.2 Missing Categories

| Category | Path | Priority |
|----------|------|----------|
| Xcode Device Support | `~/Library/Developer/Xcode/iOS DeviceSupport` | High |
| Xcode Watch Support | `~/Library/Developer/WatchDeviceSupport` | Medium |
| Old Xcode versions | `/Applications/Xcode*.app` | Medium |
| Mail downloads | `~/Library/Mail Downloads` | Medium |
| Messages attachments | `~/Library/Messages/Attachments` | ✅ Done |
| Screen recordings | `~/Movies/Screen Recordings` | Low |
| Screenshots | `~/Desktop/*Screenshot*.png` | Low |
| Duplicates | (requires algorithm) | Low |

### 4.3 Disk Visualization

**Learn from diskonaut (MIT):**
- Treemap visualization of disk usage
- Interactive - click to drill down
- Show files/folders by size
- Delete directly from visualization

**Recommendation:**
- Add a "Disk Explorer" tab to the Disk view
- Use SwiftUI Canvas for treemap
- Allow drill-down into folders
- Show largest files at each level

---

## 5. Smart Suggestions Improvements

### 5.1 Current Suggestions

| Suggestion Type | Status |
|-----------------|--------|
| Close browser tabs | ✅ |
| Restart apps | ✅ |
| Clean Downloads | ✅ |
| Stop Docker | ✅ |
| Clean Time Machine | ✅ |
| Clean iOS Updates | ✅ |
| Clean node_modules | ✅ |

### 5.2 Missing Suggestions

- [ ] **Battery drain detection** - Apps using significant power
- [ ] **Startup item optimization** - Too many login items
- [ ] **Large attachment warning** - Messages attachments > 1GB
- [ ] **Unused app detection** - Apps not opened in 30+ days
- [ ] **Low disk space prediction** - "At current rate, disk will be full in X days"
- [ ] **Memory leak detection** - Apps with growing memory over time
- [ ] **Swap usage alert** - High swap indicates memory pressure
- [ ] **Update recommendations** - macOS, Xcode, Homebrew updates available

### 5.3 Machine Learning Opportunity

Could use simple heuristics or CoreML for:
- Learn user's "normal" memory usage patterns
- Detect anomalies (unusual spikes)
- Predict best time for cleanup
- Personalize suggestions based on usage

---

## 6. Open Source Libraries to Consider

### 6.1 MIT Licensed (Safe to use)

| Library | Purpose | GitHub |
|---------|---------|--------|
| **SMCKit** | SMC/Sensor reading | Used by Stats |
| **oslog** | Structured logging | Apple |
| **LaunchAtLogin** | Startup items | LaunchAtLogin-Modern |

### 6.2 GPL Licensed (Learn from, don't copy)

| Project | Learn From |
|---------|------------|
| Objective-See tools | Security scanning techniques |
| Stats | Menu bar architecture, SMC reading |
| BleachBit | Cleaner definitions XML format |

### 6.3 Recommended Dependencies

**Add to Package.swift:**
```swift
dependencies: [
    // Launch at login (modern SwiftUI)
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.0.0"),
    
    // Logging
    .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
]
```

---

## 7. Implementation Priority

### Phase 1: Quick Wins (1-2 days)
1. Add temperature monitoring (from Stats/SMCKit)
2. Add package manager caches to optimizer
3. Add browser extension scanning
4. Add cron job scanning
5. Add code signing verification for security items

### Phase 2: Medium Effort (3-5 days)
1. Add historical charts (Swift Charts)
2. Add disk treemap visualization
3. Enhance smart suggestions
4. Add more cache categories
5. Improve health score with letter grade

### Phase 3: Major Features (1-2 weeks)
1. Endpoint Security for real-time monitoring
2. NetworkExtension for network monitoring
3. Scheduled cleanup feature
4. Cleanup history
5. Export/import settings

### Phase 4: Polish (1 week)
1. App icon design
2. Notarization for distribution
3. Sparkle for auto-updates
4. Help documentation
5. Onboarding flow

---

## 8. Key Metrics to Track

| Metric | Current | Target |
|--------|---------|--------|
| Security scan time | ~5s | <3s |
| Cache detection accuracy | ~80% | >95% |
| Memory usage (app) | Unknown | <50MB |
| Launch time | Unknown | <1s |
| User suggestions acted on | Unknown | Track |

---

## 9. Files That Would Change

### New Files
- `MemoryMonitor/Sources/Services/TemperatureMonitor.swift`
- `MemoryMonitor/Sources/Services/FanMonitor.swift`
- `MemoryMonitor/Sources/Services/HistoryStore.swift`
- `MemoryMonitor/Sources/Services/BrowserExtensionScanner.swift`
- `MemoryMonitor/Sources/Services/CronJobScanner.swift`
- `MemoryMonitor/Sources/Services/CodeSignVerifier.swift`
- `MemoryMonitor/Sources/Views/DiskExplorerView.swift`
- `MemoryMonitor/Sources/Views/HistoryChartsView.swift`

### Modified Files
- `SecurityScanner.swift` - Add more scan types
- `ComprehensiveOptimizer.swift` - Add more cache types
- `StorageAnalyzer.swift` - Add more categories
- `SmartSuggestions.swift` - Add more suggestion types
- `HealthView.swift` - Add temperature, charts
- `DiskView.swift` - Add disk explorer

---

## 10. Next Steps

**Recommended starting point:**

1. **Temperature Monitoring** - High impact, learn from Stats
2. **Historical Charts** - User-visible improvement
3. **Additional Cache Categories** - More cleaning power

**Question for user:** Which improvements are most valuable to you?