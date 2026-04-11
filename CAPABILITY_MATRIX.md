# Pulse Capability Matrix

> Accurate status of all Pulse features as of March 2026
> 
> **Status Legend:**
> - ✅ **WORKING** - Feature works as described
> - ⚠️ **PARTIAL** - Feature works but with limitations
> - 🔍 **HEURISTIC** - Feature uses estimation/rules, not definitive
> - ❌ **NOT IMPLEMENTED** - Feature claimed but not built

---

## Feature Renaming (March 2026)

| Old Name | New Name | Reason |
|----------|----------|--------|
| "Memory Optimizer" | "Memory Advisor" | Cannot optimize memory, only advise |
| "AI-Powered" | "Rules-Based" | No ML/AI, uses threshold rules |
| "Real-Time Monitoring" | "Persistence Watcher" | File watchers only, not kernel-level |
| "Keylogger Detection" | "Suspicious Process Scanner" | Heuristic only, not definitive |

---

## System Monitoring

| Feature | Status | Notes |
|---------|--------|-------|
| Memory usage monitoring | ✅ WORKING | Uses mach VM APIs, accurate |
| Memory pressure detection | ✅ WORKING | Kernel pressure events + percentage fallback |
| Per-process memory tracking | ✅ WORKING | Uses proc_pidinfo, accurate RSS |
| CPU usage monitoring | ✅ WORKING | host_processor_info API |
| Per-core CPU gauges | ⚠️ PARTIAL | Shows total CPU, per-core not implemented in UI |
| CPU history chart | ⚠️ PARTIAL | Data collected, chart view exists |
| Disk usage monitoring | ✅ WORKING | FileManager volume URLs |
| Volume list | ✅ WORKING | All mounted volumes shown |
| Network throughput | ✅ WORKING | getifaddrs for interface stats |
| Network history chart | ⚠️ PARTIAL | Data collected, chart view exists |
| Battery percentage | ✅ WORKING | pmset parsing |
| Battery cycle count | ✅ WORKING | ioreg parsing |
| Battery health estimate | 🔍 HEURISTIC | Based on cycle count only, not actual capacity |
| Thermal state | ✅ WORKING | ProcessInfo.thermalState |
| Temperature monitoring | ⚠️ PARTIAL | SMC reading implemented, may not work on all Macs |

---

## Health Score

| Feature | Status | Notes |
|---------|--------|-------|
| A-F grade calculation | ✅ WORKING | Based on memory, CPU, swap, thermal, disk |
| Score 0-100 | ✅ WORKING | 100 - penalties |
| Health breakdown | ✅ WORKING | Shows penalty categories |
| Letter grade in UI | ✅ WORKING | Displayed in health orb |
| Trend indicator | ❌ NOT IMPLEMENTED | No historical comparison |

---

## Optimization & Cleanup (Memory Advisor)

| Feature | Status | Notes |
|---------|--------|-------|
| Memory "optimization" | ⚠️ PARTIAL | Renamed to "Memory Advisor" - closes idle apps, clears caches |
| Cache cleanup | ✅ WORKING | Developer, browser, system caches |
| **Trash-based deletion** | ✅ WORKING | ALL deletions go to Trash (recoverable). Caches are trashed then empty folder recreated. |
| **Operation manifests** | ⚠️ PARTIAL | Logs cleanup actions, no restore from Trash |
| Xcode DerivedData cleanup | ✅ WORKING | Deletes ~/Library/Developer/Xcode/DerivedData |
| iOS Device Support cleanup | ✅ WORKING | Deletes old Xcode device support files |
| Docker cleanup | ⚠️ PARTIAL | Requires Docker CLI, preview with `docker system df` |
| node_modules cleanup | ✅ WORKING | Scans and deletes selected folders |
| Time Machine snapshots | ✅ WORKING | tmutil deletelocalsnapshots |
| iOS updates cleanup | ✅ WORKING | Deletes ~/Library/iTunes/iOS Updates |
| iOS backups cleanup | ✅ WORKING | Deletes ~/Library/Application Support/MobileSync/Backup |
| Large files finder | ✅ WORKING | Scans common locations, top 20 shown |
| Downloads cleanup | ⚠️ PARTIAL | Shows old files, moves to Trash (not permanent) |
| Messages attachments | ✅ WORKING | Shows size, moves to Trash |
| Trash emptying | ✅ WORKING | Deletes ~/.Trash contents |
| DNS flush | ✅ WORKING | dscacheutil + mDNSResponder kill |
| Idle app closing | ✅ WORKING | Closes apps without visible windows |
| Cleanup preview | ✅ WORKING | Shows items before deletion with size estimates |
| Undo after cleanup | ❌ NOT IMPLEMENTED | Trash items can be restored manually |
| Scheduled cleanup | ❌ NOT IMPLEMENTED | Manual only |
| Cleanup history | ⚠️ PARTIAL | Shows total freed, count - no detailed log |

---

## Process Management

| Feature | Status | Notes |
|---------|--------|-------|
| Process list | ✅ WORKING | Top processes by memory |
| Process icons | ✅ WORKING | Cached from NSWorkspace |
| Manual process kill | ✅ WORKING | SIGTERM then SIGKILL |
| Auto-kill (Runaway Guard) | ✅ WORKING | Configurable thresholds |
| Process whitelist | ✅ WORKING | 60+ system processes protected |
| Warning before kill | ✅ WORKING | NSAlert with 3 options |
| Kill log | ✅ WORKING | Last 100 kills logged |

---

## Security Scanner (Persistence Watcher)

| Feature | Status | Notes |
|---------|--------|-------|
| LaunchAgents scan | ✅ WORKING | ~/Library/LaunchAgents, /Library/LaunchAgents |
| LaunchDaemons scan | ✅ WORKING | /Library/LaunchDaemons, /System/Library/LaunchDaemons |
| Login Items scan | ⚠️ PARTIAL | Only ~/Library/LoginItems - misses System Settings items (Sonoma+) |
| Suspicious Process Scanner | 🔍 HEURISTIC | Renamed from "Keylogger Detection" - checks for suspicious names only |
| File watchers | ⚠️ PARTIAL | Detects file changes, requires Full Disk Access |
| Browser extensions scan | ✅ WORKING | Safari, Chrome, Firefox |
| Cron jobs scan | ✅ WORKING | /etc/crontab, /etc/periodic |
| Code signing verification | ❌ NOT IMPLEMENTED | CodeSignVerifier exists but not integrated |
| VirusTotal lookup | ❌ NOT IMPLEMENTED | Not built |
| Threat notifications | ⚠️ PARTIAL | UNUserNotificationCenter, requires permission |
| Persistence item disable | ⚠️ PARTIAL | Can unload launchd items, not login items |
| Full Disk Access check | ✅ WORKING | Tests /Library/Application Support/com.apple.TCC readability |
| Accessibility permission check | ✅ WORKING | AXIsProcessTrusted |
| **Endpoint Security** | ❌ NOT IMPLEMENTED | Requires system extension (future Security Extension) |
| **Real-time blocking** | ❌ NOT IMPLEMENTED | Only alerts, cannot block (requires Endpoint Security) |

---

## Developer Tools

| Feature | Status | Notes |
|---------|--------|-------|
| Xcode detection | ✅ WORKING | Checks for DerivedData folder |
| Docker detection | ✅ WORKING | pgrep docker |
| Node.js detection | ✅ WORKING | which node |
| Homebrew detection | ✅ WORKING | which brew |
| Profile-based cleanup | ✅ WORKING | Custom actions per tool |
| Custom rules | ✅ WORKING | User-defined shell commands |
| Disk usage per profile | ✅ WORKING | Shows size per category |

---

## User Interface

| Feature | Status | Notes |
|---------|--------|-------|
| Menu bar integration | ✅ WORKING | LSUIElement=true, always running |
| Menu bar adaptive content | ✅ WORKING | Lite mode vs full popover |
| Dashboard window | ✅ WORKING | 9-tabs with sidebar navigation |
| Settings window | ✅ WORKING | Accessible via ⌘, |
| Dark mode | ✅ WORKING | SwiftUI automatic |
| Health orb visualization | ✅ WORKING | Circular progress with grade |
| Memory breakdown bar | ✅ WORKING | Color-coded segments |
| History charts | ⚠️ PARTIAL | Sparkline views exist, full charts incomplete |
| Notifications | ✅ WORKING | UNUserNotificationCenter |
| Haptic feedback | ✅ WORKING | NSHapticFeedbackManager |
| Keyboard shortcuts | ✅ WORKING | ⌘, for settings, ⌘W for close |
| Launch at login | ✅ WORKING | SMAppService |

---

## AI / Intelligence Claims

| Claim | Status | Reality |
|-------|--------|---------|
| "AI-Powered" | ❌ RENAMED | No ML/AI code exists; renamed to "Rules-Based Recommendations" |
| "Smart recommendations" | 🔍 HEURISTIC | Rule-based if-then logic (threshold checks) |
| "Intelligent optimization" | 🔍 HEURISTIC | Predefined cleanup rules, no learning |
| "Machine learning" | ❌ NOT IMPLEMENTED | No CoreML, no training, no adaptation |
| "Memory Optimizer" | ⚠️ RENAMED | Renamed to "Memory Advisor" - cannot optimize kernel memory |

---

## Permissions & Entitlements

| Permission | Status | Notes |
|------------|--------|-------|
| Full Disk Access | ⚠️ PARTIAL | Requested via UI, no entitlements file in SPM |
| Accessibility | ⚠️ PARTIAL | AXIsProcessTrusted checked, prompt available |
| Apple Events | ⚠️ PARTIAL | Used for Safari tab count, no entitlements |
| Notifications | ✅ WORKING | UNUserNotificationCenter.requestAuthorization |
| Launch at Login | ✅ WORKING | SMAppService.mainApp |

---

## Known Limitations

1. **Memory "optimization" cannot purge kernel memory** - macOS manages this automatically
2. **Suspicious Process Scanner is heuristic only** - Cannot access other apps' accessibility permissions without FDA
3. **Login Items scan incomplete** - macOS Sonoma+ stores in System Settings, not files
4. **Undo via Trash** - ALL items go to Trash first (recoverable via macOS). Empty Trash for permanent delete.
5. **Temperature reading may fail** - SMC access varies by Mac model, especially Apple Silicon
6. **Docker cleanup requires CLI** - /usr/local/bin/docker must exist
7. **No real Endpoint Security** - File watchers only, not kernel-level monitoring (future Security Extension)
8. **Health score is snapshot only** - No trend analysis over time (HistoricalMetricsService not integrated)

---

## What Pulse Actually Does

**Pulse is a system monitoring dashboard with cache cleanup capabilities.**

It can:
- ✅ Show you what's using memory, CPU, disk, network
- ✅ Close apps you're not using
- ✅ Delete cache files that will regenerate (ALL deletions go to Trash for recovery)
- ✅ Alert you when resources are high
- ✅ Find large files and old backups
- ✅ List startup items for review
- ✅ Preview Docker cleanup before executing (`docker system df`)
- ✅ Detect suspicious process names (heuristic, not definitive)

It cannot:
- ❌ Force macOS to free RAM (kernel manages this)
- ❌ Definitively detect keyloggers (requires FDA + deeper access)
- ❌ Learn from your behavior (no ML/AI)
- ❌ Block malware installation (only alerts after the fact)
- ❌ Replace dedicated security tools (no virus scanning)
- ❌ Monitor process execution in real-time (requires Endpoint Security framework)

---

## Phase 1 Safety Fixes (April 11, 2026)

**5 critical safety issues resolved:**

| # | Fix | Before | After |
|---|---|---|---|
| 1 | fullOptimize() bypass | Auto-deleted files without confirmation | Redirects to scanForCleanup() -> requires user confirmation |
| 2 | ~/Library/Mail cleanup | Targeted entire Mail directory (actual emails) | Removed from scan entirely |
| 3 | Trash-based deletion | Caches permanently deleted (no recovery) | ALL deletions go to Trash (recoverable) |
| 4 | DiskSpaceGuardian auto-cleanup | Called executeCleanup() -> fullOptimize() bypass | Uses quickOptimize() (safe: idle apps + DNS only) |
| 5 | Test helper mismatch | Downloads folder not protected in tests | Aligned with production code |

**Verification:**
- `swift build`: PASS (0 errors, 0 warnings)
- `swift test`: PASS (73/73 runnable tests, 0 failures)
- SafetyFeaturesTests: All 11 tests pass including new Downloads protection tests

*Last updated: April 11, 2026*
*Version: 1.2 (pre-release, Phase 1 safety complete)*
