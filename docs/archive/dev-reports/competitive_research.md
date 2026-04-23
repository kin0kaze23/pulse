# Pulse Competitive Research Report
# Mac Optimization Tools & macOS Security Best Practices
# Generated: 2026-04-11

---

## 1. TOOL COMPARISON

### 1.1 Mole (tw93/Mole) - 46k+ Stars, Go CLI
**Unique Strengths:**
- `mo purge` - Scans project directories for build artifacts (node_modules, build, dist, .venv, etc.) across the filesystem. Pulse does NOT have this cross-directory artifact purge.
- `mo installer` - Detects and removes leftover .dmg/.pkg/.zip files from Downloads, Desktop, iCloud, Homebrew caches. Pulse lacks installer cleanup.
- `mo touchid` - Enables Touch ID authentication for sudo commands. Pulse does not integrate Touch ID.
- `mo completion` - Shell tab-autocompletion support. Not applicable to GUI apps.
- Whitelist management for protecting specific cache paths during cleanup. Pulse has some whitelist support but it's less featured.
- Quick Look file preview (qlmanage) inside the analyze TUI. Unique to Mole's TUI.

**Safety Approach:**
- `--dry-run` before all destructive operations
- `--debug` flag shows full file paths and risk levels
- Whitelist for protected paths
- Won't touch critical system files
- Shell syntax check, shfmt, shellcheck, and go vet on commits (strong CI)

### 1.2 DodoTidy (DodoApps/dodotidy) - 173 Stars, SwiftUI
**Unique Strengths:**
- Trash-based deletion system - ALL deletions use macOS `trashItem()` API, making recovery trivial. Pulse uses direct deletion. This is the biggest safety differentiator.
- Scheduled cleaning with UserNotifications integration - alerts before executing automated cleanups. Pulse has AutomationScheduler but lacks the pre-execution notification confirmation.
- "Confirm scheduled tasks" toggle - prevents surprise background deletions.
- Real-time dashboard with Combine framework (60fps) tracking CPU, memory, disk I/O, battery health, AND Bluetooth devices. Pulse lacks Bluetooth device monitoring.
- User-space only - no sudo, no root access, zero risk to system files.
- SQLite operation history log. Pulse has HistoricalMetricsService but not a full operation audit log.
- Protected paths by default: Documents, Desktop, SSH keys, cloud credentials.
- Dry-run mode with preview before cleaning.

**Safety Approach (IMPORTANT LESSON):**
- DodoTidy REMOVED its orphaned app data detection feature entirely due to safety concerns. The matching logic between folder names and installed apps was too imprecise, causing false positives where active app data (Telegram, Outlook) was flagged. This is a critical lesson for Pulse.
- Every deletion uses trashItem() API for easy recovery.
- All items default to UNSELECTED, requiring explicit user confirmation.

### 1.3 OptiMac (VonKleistL/OptiMac) - 260 Stars, Swift/SwiftUI
**Unique Strengths:**
- System tweaks category - Pulse has NONE of these:
  - Purge inactive memory (ramdisk/OS command)
  - Optimize swap settings
  - Reduce/disable system animations
  - Remove Dock animations
  - Disable Finder animations
  - Optimize Launchpad
  - Disable Dashboard
  - Enable SSD TRIM
- Network optimizations category:
  - DNS cache flushing (Pulse has some of this)
  - TCP/IP optimization
  - Wi-Fi enhancements
  - IPv6 management
- Developer environment tuning:
  - Python/Conda optimization for Apple Silicon
  - Git performance tuning
  - Homebrew cleanup
  - Node.js configuration
- Profile management with saved optimization profiles
- Menu Bar Mode (lightweight tray integration)
- Automatic Time Machine backup before major changes
- All optimizations are reversible (toggle on/off)

**Safety Approach:**
- Non-destructive changes - all optimizations reversible
- Backup integration before major changes
- Confirmation dialogs for system modifications
- Detailed logging of all changes
- Conservative safe defaults
- Profile validation

### 1.4 MacCleanCLI (QDenka/MacCleanCLI) - 30 Stars, Python
**Unique Strengths:**
- Priority-based cleaning system (HIGH, MEDIUM, LOW, OPTIONAL) - Pulse does not have this categorization.
- Duplicate file detection - Pulse does NOT have duplicate file scanning.
- Large file detection (files over 100MB) - Pulse has LargeFileFinder but MacCleanCLI integrates it into the priority system.
- Old file detection (not accessed in 6+ months) - Pulse does NOT have this.
- Detailed file preview before cleaning with pagination (20 files per batch) - shows exactly what will be deleted with sizes and safety indicators.
- Optional backup system with configurable retention period.
- Post-cleaning verification - confirms files were actually deleted.
- 19+ scanning categories with multi-threaded scanning.
- Startup items management (LaunchAgents/Daemons/LoginItems) - Pulse has CronJobScanner but not full startup item management.
- Pattern-based file identification with safety checks.

**Safety Approach:**
- Protected system paths and directories
- Confirmation prompts for destructive operations
- Automatic backup before deletion (configurable retention)
- Post-cleaning verification
- Built-in protection for system-critical files
- Dry-run mode

---

## 2. FEATURES PULSE IS MISSING

### High Priority Gaps:
1. **Duplicate File Detection** - MacCleanCLI has it. None of Pulse's services handle this.
2. **App Uninstaller** - Mole, DodoTidy, and OptiMac all have complete app uninstallation (app + support files + preferences + logs + launch agents). Pulse has NO app uninstaller.
3. **Trash-Based Deletion** - DodoTidy's approach of using `NSWorkspace.shared.recycle()` instead of direct deletion. Critical for user safety.
4. **System Tweaks** - OptiMac's disable animations, Dock optimizations, Launchpad optimizations, SSD TRIM. Pulse does none of these.
5. **Priority-Based Cleaning** - MacCleanCLI's HIGH/MEDIUM/LOW/OPTIONAL categorization. Pulse has safety levels but not priority tiers.
6. **Old File Detection** - MacCleanCLI scans for files not accessed in 6+ months. Pulse lacks this.
7. **Network Optimization Suite** - OptiMac's TCP/IP, Wi-Fi, IPv6 management. Pulse has DNS flush only.
8. **Installer Cleanup** - Mole's `.dmg/.pkg/.zip` detection in Downloads/Desktop. Pulse lacks this.
9. **Build Artifact Purge** - Mole's cross-directory `node_modules`, `build`, `dist`, `.venv` scanning. Pulse cleans dev caches but doesn't scan project directories for build artifacts.
10. **Startup Items Manager** - MacCleanCLI manages LaunchAgents/Daemons/LoginItems. Pulse has CronJobScanner but not full startup item management.

### Medium Priority Gaps:
11. **Bluetooth Device Monitoring** - DodoTidy shows connected Bluetooth devices. Pulse doesn't.
12. **Pre-Execution Notifications** - DodoTidy's scheduled task confirmation via UserNotifications.
13. **Operation History/Audit Log** - DodoTidy's SQLite log of all operations. Pulse has metrics history but not a cleanup audit trail.
14. **Backup System with Retention** - MacCleanCLI and OptiMac have configurable backup before deletion. Pulse does not.
15. **Post-Cleaning Verification** - MacCleanCLI verifies files were actually deleted. Pulse does not.
16. **Touch ID Integration** - Mole's `mo touchid` for sudo authentication.
17. **Reversible Optimizations** - OptiMac's toggle-on/off for all system tweaks.
18. **Time Machine Integration** - OptiMac triggers backup before major changes.

### Low Priority / Nice-to-Have:
19. **Shell Completion** - Mole's tab autocomplete (not applicable to GUI app).
20. **Menu Bar Mode** - OptiMac's lightweight tray mode. Pulse already has menu bar integration.
21. **Quick Look Preview** - Mole's qlmanage in TUI (not directly applicable).

---

## 3. macOS SECURITY BEST PRACTICES FOR OPTIMIZATION

### 3.1 System Integrity Protection (SIP)
- SIP protects `/System`, `/usr`, `/bin`, `/sbin`, and pre-installed Apple apps.
- These directories CANNOT be modified even by root unless SIP is disabled.
- OPTIMIZATION TOOLS must NEVER attempt to modify SIP-protected paths.
- Safe paths for cleanup: `~/Library/Caches`, `~/Library/Logs`, `~/Library/Application Support`, `/private/var/tmp`, `/private/tmp`.

### 3.2 TCC (Transparency, Consent, and Control)
- TCC controls access to sensitive locations: Desktop, Documents, Downloads, iCloud Drive, removable volumes.
- Full Disk Access (FDA) is required to scan/clean all user directories.
- TCC permissions are inherited - if Terminal has FDA, scripts it runs inherit it.
- Optimization tools should request only the permissions they need and explain why.

### 3.3 Safe Files to Delete:
- `~/Library/Caches/*` - Application caches (safe, will regenerate)
- `~/Library/Logs/*` - User-level log files (mostly safe)
- `/private/var/tmp/*` - System temp files (safe if not locked/in-use)
- `/private/tmp/*` - Temp files (cleared on reboot anyway)
- `~/Library/Developer/Xcode/DerivedData/*` - Xcode build artifacts (safe)
- `~/Library/Containers/com.docker.docker/...` - Docker data (caution)
- Trash contents (safe)
- `~/Downloads/*.dmg, *.pkg, *.zip` - Old installers (safe but user data risk)

### 3.4 Dangerous Files to NEVER Delete:
- Anything in `/System` - SIP protected, critical for OS
- `/Library` (root-level) - System-wide configs, can break apps
- `~/Library/Preferences/*.plist` - App preferences, may cause data loss
- `~/Library/Application Support/` - App data (selective only, never bulk)
- `~/.ssh/`, `~/.gnupg/` - SSH/GPG keys
- Cloud credential files (aws, gcloud, azure configs)
- `~/Documents/`, `~/Desktop/` - User files
- `.DS_Store` files - Not worth the risk, some apps depend on them

### 3.5 Hidden File Locations:
- **Caches:** `~/Library/Caches`, `/Library/Caches`, `/System/Library/Caches`
- **Logs:** `/private/var/log`, `~/Library/Logs`, `/Library/Logs/DiagnosticReports`
- **Crash Reports:** `/Library/Application Support/CrashReporter`
- **Temp Files:** `/private/var/tmp`, `/private/tmp`
- **Launch Items:** `~/Library/LaunchAgents`, `/Library/LaunchAgents`, `/Library/LaunchDaemons`
- **App Support:** `~/Library/Application Support`, `/Library/Application Support`
- **Containers:** `~/Library/Containers` (sandboxed app data)
- **Preferences:** `~/Library/Preferences`

### 3.6 Key Security Principles for Optimization Tools:
1. User-space operations preferred (no sudo/root)
2. Trash-based deletion > direct deletion (enables recovery)
3. Default to UNSELECTED for risky categories (require opt-in)
4. Dry-run preview before all destructive operations
5. Protected path lists (never touch SSH keys, cloud credentials, Documents)
6. Explicit user confirmation for bulk operations
7. Detailed logging of all changes made
8. Reversible operations where possible
9. No modification of SIP-protected paths
10. Request minimum required TCC permissions
11. Learn from DodoTidy's orphaned data removal - imprecise matching can cause data loss

---

## 4. RECOMMENDED PRIORITY ACTIONS FOR PULSE

### Phase 1 - Critical Safety & Missing Features:
1. Implement trash-based deletion (NSWorkspace.shared.recycle)
2. Add duplicate file detection
3. Add app uninstaller (with careful, precise matching - learn from DodoTidy's lesson)
4. Add installer cleanup (.dmg/.pkg/.zip)

### Phase 2 - System Optimization:
5. Add system tweaks panel (animations, Dock, Launchpad, SSD TRIM)
6. Add network optimization suite (TCP/IP, Wi-Fi, IPv6)
7. Add old file detection (not accessed in X months)
8. Add priority-based cleaning categories (HIGH/MEDIUM/LOW/OPTIONAL)

### Phase 3 - Safety & UX:
9. Add backup system with configurable retention
10. Add post-cleaning verification
11. Add startup items manager (LaunchAgents/Daemons)
12. Add operation history/audit log
13. Add pre-execution notifications for scheduled tasks
