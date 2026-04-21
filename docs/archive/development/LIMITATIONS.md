# Pulse Limitations

> Honest documentation of what Pulse cannot do and why

---

## Critical Limitations

### 1. Memory "Optimization" is Misleading

**Claim:** Pulse can "optimize" or "free" memory.

**Reality:** 
- macOS automatically manages memory via the kernel
- Pulse can only:
  - Close applications (terminates processes)
  - Delete cache files (frees disk, not RAM directly)
  - Flush DNS cache (network, not memory)
- Pulse **cannot**:
  - Force the kernel to purge compressed memory
  - Clear wired memory (kernel-reserved)
  - Reduce memory pressure (only time helps)
  - Stop memory leaks in other apps

**Why:** macOS uses a sophisticated memory management system (VM compressor, purgeable memory, memory pressure). User-space apps cannot override kernel decisions.

**Recommendation:** If memory pressure is high, close unused apps or restart your Mac. Pulse can help identify which apps use the most memory, but cannot magically "free" RAM.

---

### 2. Keylogger Detection is Heuristic Only

**Claim:** Pulse can "detect keyloggers".

**Reality:**
- Pulse checks for suspicious process names (e.g., "keylog", "screen_capture")
- Pulse checks if apps have Accessibility permission (via AXIsProcessTrusted)
- Pulse **cannot**:
  - See which other apps have Accessibility permission (requires Full Disk Access)
  - Detect kernel-level keyloggers
  - Detect hardware keyloggers
  - Scan app binaries for malicious code

**Why:** macOS security (TCC - Transparency, Consent, and Control) protects accessibility permissions data. Only apps with Full Disk Access can read `/Library/Application Support/com.apple.TCC/TCC.db`, and even then, direct SQLite access is blocked on modern macOS.

**Recommendation:** Use dedicated security tools like:
- Objective-See's KnockKnock (persistence scanner)
- Objective-See's ReiKey (keylogger detection)
- Malwarebytes for Mac

---

### 3. "Real-Time Monitoring" is File Watching Only

**Claim:** Pulse provides "real-time threat monitoring".

**Reality:**
- Pulse uses DispatchSourceFileSystemObject to watch specific directories
- This only detects file changes, not process behavior
- Pulse **cannot**:
  - Monitor process execution (requires Endpoint Security framework)
  - Block malicious actions (only alerts after the fact)
  - Detect network-based threats
  - Scan for malware signatures

**Why:** True real-time monitoring requires the Endpoint Security framework, which needs:
- System extension entitlement (Apple approval required)
- User approval in System Settings → Privacy & Security
- Complex event handling infrastructure

**Recommendation:** Pulse's file watchers can alert you to new startup items, but cannot prevent malware installation. Use a dedicated security suite for real-time protection.

---

### 4. Login Items Scan is Incomplete

**Claim:** Pulse scans "login items".

**Reality:**
- Pulse scans `~/Library/LoginItems` (legacy location)
- Pulse **cannot** scan:
  - System Settings → General → Login Items (macOS Sonoma+)
  - Apps that auto-launch via other mechanisms
  - Helper apps embedded in other applications

**Why:** macOS Sonoma moved login items to a system-controlled database that is not directly readable by third-party apps.

**Recommendation:** Check System Settings → General → Login Items manually for a complete list.

---

### 5. Deletion is Mixed: Some Files Go to Trash, Some Are Permanent

**Claim:** Pulse can "clean up" files.

**Reality:**
- Pulse uses **mixed deletion strategy**:
  - **Caches** (DerivedData, node_modules, browser caches): **Permanent delete** — files cannot be recovered
  - **User data** (Downloads, Logs, Messages attachments): **Trash** — files can be recovered from Trash
  - **iOS Updates/Backups**: **Permanent delete** — large binary files, permanently removed
  - **Time Machine snapshots**: **Permanent delete** via `tmutil deletelocalsnapshots`
- No snapshot/backup before deletion
- No "undo" button after cleanup (but Trash items can be restored)

**Why:** Caches regenerate automatically, so permanent delete is safe. User data is irreplaceable, so it goes to Trash for recovery.

**Recommendation:**
- Review the cleanup plan carefully before confirming
- Check Trash after cleanup if you need to recover anything
- Ensure Time Machine backups are current before using cleanup features

---

### 6. Temperature Reading May Fail

**Claim:** Pulse shows CPU/GPU temperature.

**Reality:**
- Uses SMC (System Management Controller) via IOKit
- Works on most Intel Macs
- May not work on Apple Silicon Macs (M1/M2/M3) due to different sensor architecture
- Some sensors may return 0 or invalid values

**Why:** Apple Silicon uses a different thermal management system. SMC keys that work on Intel may not exist or return valid data on Apple Silicon.

**Recommendation:** If temperature shows 0°C or doesn't update, your Mac model may not support SMC-based temperature reading. Use iStat Menus or Stats app for more comprehensive sensor support.

---

### 7. Health Score is a Snapshot, Not a Trend

**Claim:** Pulse shows your Mac's "health score".

**Reality:**
- Score is calculated from current metrics only
- No historical comparison (e.g., "score improved 10 points this week")
- No personalized baseline (what's "normal" varies by Mac)
- Penalties are arbitrary (why is swap >5GB worth 20 points?)

**Why:** HistoricalMetricsService exists but is not integrated into the health score calculation.

**Recommendation:** Use the health score as a rough guide, not a definitive measurement. A "B" grade doesn't mean your Mac is unhealthy - it means current metrics have some penalties.

---

### 8. Docker Cleanup Requires CLI

**Claim:** Pulse can "clean Docker".

**Reality:**
- Requires `/usr/local/bin/docker` to exist
- Only works if Docker Desktop is running
- Commands like `docker system prune -af` are destructive
- No preview of what will be deleted

**Why:** Docker doesn't expose a native macOS API. Pulse shells out to the Docker CLI.

**Recommendation:** Use Docker Desktop's built-in cleanup tools or `docker system df` to preview what will be deleted before using Pulse's Docker cleanup.

---

### 9. No AI or Machine Learning

**Claim:** (Implied) Pulse is "smart" or "intelligent".

**Reality:**
- Zero ML/AI code in the codebase
- No CoreML models
- No Apple Neural Engine usage
- No learning from user behavior
- "Smart suggestions" are hardcoded if-then rules

**Why:** Building ML features requires:
- Training data (not available)
- CoreML expertise (not in scope)
- Privacy considerations (user data collection)

**Recommendation:** Think of Pulse as a rules-based automation tool, not an AI assistant.

---

### 10. Entitlements Not Configured for Distribution

**Claim:** Pulse can access system directories.

**Reality:**
- No `.entitlements` file in Swift Package Manager build
- Full Disk Access must be granted manually
- Code signing is ad-hoc (`codesign --force --deep --sign -`)
- Not notarized (will trigger Gatekeeper warnings)

**Why:** SPM doesn't support entitlements configuration. A proper Xcode project is needed for:
- Entitlements file integration
- Code signing with Developer ID
- Notarization submission

**Recommendation:** For local use, grant Full Disk Access manually. For distribution, create an Xcode project and configure proper signing.

---

## What Pulse Is

**Pulse is a system monitoring dashboard with cache cleanup automation.**

It's useful for:
- ✅ Developers who want to see memory/CPU usage at a glance
- ✅ Users who want to clean Xcode caches safely
- ✅ Finding large files and old backups
- ✅ Identifying which apps use the most resources
- ✅ Automating repetitive cleanup tasks

---

## What Pulse Is Not

**Pulse is not:**
- ❌ A replacement for Activity Monitor (less accurate, fewer features)
- ❌ A security suite (no malware scanning, no firewall)
- ❌ A memory booster (macOS manages memory automatically)
- ❌ An AI assistant (no learning, no adaptation)
- ❌ A backup tool (deletes files, doesn't preserve them)
- ❌ A system optimizer in the traditional sense (cannot change kernel behavior)

---

## When NOT to Use Pulse

Do not use Pulse if:
- You expect it to "speed up" your Mac (it won't, unless you're memory-pressure limited)
- You want malware protection (use a dedicated security tool)
- You don't have backups (cleanup is permanent)
- You need 100% accurate temperature readings (use iStat Menus)
- You want to monitor login items completely (check System Settings manually)

---

## Known Bugs and Edge Cases

| Issue | Impact | Workaround |
|-------|--------|------------|
| Health score tests crash | Tests fail in XCTest context | Skip tests that access MemoryMonitorManager.shared |
| Temperature shows 0°C | Apple Silicon Macs | Use external sensor app |
| Docker cleanup fails | Docker not at /usr/local/bin | Install Docker CLI or skip Docker cleanup |
| Login items incomplete | macOS Sonoma+ | Check System Settings manually |
| Menu bar shows stale data | Refresh interval too long | Reduce refresh interval in Settings |
| Cleanup preview doesn't show full paths | UX limitation | Check logs after cleanup |

---

*Last updated: March 27, 2026*
*Version: 1.1 (pre-release)*
