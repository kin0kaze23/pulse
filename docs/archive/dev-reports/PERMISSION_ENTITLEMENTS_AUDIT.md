# Permission & Entitlements Audit

> Audit of Pulse's permission-dependent features and their corresponding entitlements

**Date:** March 27, 2026  
**Version:** 1.1 (pre-release)

---

## Summary

| Permission Type | Status | Entitlement/Key | Features Using It |
|-----------------|--------|-----------------|-------------------|
| Full Disk Access | ✅ Documented | `NSSystemAdministrationUsageDescription` | Security scanner, cleanup |
| Accessibility | ✅ Documented | `NSAccessibilityUsageDescription` | Keylogger detection |
| Apple Events | ✅ Documented | `NSAppleEventsUsageDescription` | Browser tab counting |
| AppleScript | ✅ Documented | `NSAppleScriptUsageDescription` | App management |
| Notifications | ✅ Implicit | `UserNotifications.framework` | Alerts |

---

## Detailed Audit

### 1. Full Disk Access (FDA)

**Info.plist Key:** `NSSystemAdministrationUsageDescription`  
**Entitlement:** `com.apple.security.temporary-exception.files.absolute-path.read-write`  
**Status:** ✅ Properly configured

#### Features Requiring FDA

| Feature | Path Accessed | Purpose | Fallback Without FDA |
|---------|---------------|---------|---------------------|
| Security Scanner | `/Library/LaunchAgents` | Detect persistence | Limited to user directories |
| Security Scanner | `/Library/LaunchDaemons` | Detect system services | Limited to user directories |
| Security Scanner | `/System/Library/LaunchDaemons` | Detect system services | N/A (system protected) |
| Cleanup | `~/Library/Caches` | Clear cache files | Works (user directory) |
| Cleanup | `~/Library/Developer/Xcode` | Xcode cleanup | Works (user directory) |
| Cleanup | `/Library/Caches` | System cache cleanup | Limited |

#### Entitlement Configuration

```xml
<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
    <string>/Library/LaunchAgents</string>
    <string>/Library/LaunchDaemons</string>
    <string>/System/Library/LaunchDaemons</string>
    <string>~/Library/LaunchAgents</string>
    <string>~/Library/Caches</string>
    <string>~/Library/Developer/Xcode</string>
    <!-- ... additional paths ... -->
</array>
```

#### Verification

```bash
# Check if FDA is granted
defaults read /Library/Preferences/com.apple.TCC | grep -i pulse

# In app: try reading protected path
FileManager.default.isReadableFile(atPath: "/Library/Application Support/com.apple.TCC")
```

---

### 2. Accessibility Permission

**Info.plist Key:** `NSAccessibilityUsageDescription`  
**Entitlement:** N/A (user-granted via System Settings)  
**Status:** ✅ Properly configured

#### Features Requiring Accessibility

| Feature | API Used | Purpose | Fallback Without |
|---------|----------|---------|-----------------|
| Keylogger Detection | `AXIsProcessTrusted()` | Detect keyboard monitors | Heuristic only |
| App Monitoring | Accessibility API | Identify foreground apps | Limited |

#### Entitlement Configuration

Not applicable — this is a user-granted permission via System Settings → Privacy & Security → Accessibility.

#### Verification

```bash
# Check if Accessibility is granted
AXIsProcessTrusted()  // Returns true if granted

# In System Settings
# System Settings → Privacy & Security → Accessibility → Pulse
```

---

### 3. Apple Events

**Info.plist Key:** `NSAppleEventsUsageDescription`  
**Entitlement:** `com.apple.security.temporary-exception.apple-events`  
**Status:** ✅ Properly configured

#### Features Requiring Apple Events

| Feature | Target | Purpose | Fallback Without |
|---------|--------|---------|-----------------|
| Browser Tab Counting | Safari, Chrome, Firefox | Count open tabs | Feature unavailable |
| App Management | Finder | Get app info | Limited |
| Process Identification | System events | Identify processes | Limited |

#### Entitlement Configuration

```xml
<key>com.apple.security.temporary-exception.apple-events</key>
<true/>
```

#### Verification

```bash
# Send test Apple Event
osascript -e 'tell application "Finder" to name'

# In app: NSAppleScript execution
let script = NSAppleScript(source: "tell application \"Finder\" to name")
```

---

### 4. AppleScript

**Info.plist Key:** `NSAppleScriptUsageDescription`  
**Entitlement:** Covered by Apple Events entitlement  
**Status:** ✅ Properly configured

#### Features Requiring AppleScript

| Feature | Script | Purpose | Fallback Without |
|---------|--------|---------|-----------------|
| Tab Counting | `tell application "Safari" to count windows` | Count Safari tabs | Feature unavailable |
| App Management | Various | Control applications | Limited |

#### Verification

Same as Apple Events — AppleScript requires Apple Events entitlement.

---

### 5. Notifications

**Framework:** `UserNotifications.framework`  
**Entitlement:** N/A (implicit with hardened runtime)  
**Status:** ✅ Properly configured

#### Features Using Notifications

| Feature | Type | Purpose | Fallback Without |
|---------|------|---------|-----------------|
| Memory Alerts | Local notification | Warn on high memory | Visual indicator only |
| Cleanup Confirmation | Local notification | Confirm cleanup complete | Toast in app |

#### Entitlement Configuration

Not applicable — notifications work with standard hardened runtime.

#### Verification

```bash
# Check notification authorization
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print(settings.authorizationStatus)
}
```

---

## Hardened Runtime Entitlements

Pulse uses the following hardened runtime entitlements (required for notarization):

```xml
<!-- Automatically included with ENABLE_HARDENED_RUNTIME = YES -->
<key>com.apple.security.cs.allow-jit</key>
<true/>

<!-- Required for accessing user-selected files -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

---

## Network Entitlements

| Entitlement | Status | Purpose |
|-------------|--------|---------|
| `com.apple.security.network.client` | ✅ Enabled | Outbound connections (network monitoring) |
| `com.apple.security.network.server` | ✅ Enabled | Inbound connections (if needed) |

---

## Process Management Entitlements

| Entitlement | Status | Purpose |
|-------------|--------|---------|
| `com.apple.security.temporary-exception.process-signaling` | ✅ Enabled | Monitor and terminate processes |

---

## Gaps & Recommendations

### Current Gaps

| Gap | Impact | Recommendation |
|-----|--------|----------------|
| App Sandbox disabled | Cannot distribute via Mac App Store | Intentional — system monitoring requires it |
| Temporary exceptions | May need renewal for new macOS versions | Review entitlements with each macOS release |

### Future Considerations

1. **Endpoint Security Framework** (Future Release)
   - Would require additional entitlements
   - May need special Apple approval
   - Out of scope for V1.1

2. **System Extensions** (Not Planned)
   - Would require notarization review
   - Complex approval process
   - Not needed for current feature set

---

## Compliance Checklist

- [x] All permission usage descriptions in Info.plist
- [x] Entitlements file configured correctly
- [x] Hardened runtime enabled
- [x] Network entitlements declared
- [x] Process management entitlements declared
- [x] Temporary exceptions documented
- [x] Fallback behavior documented for each permission
- [x] User-facing explanations accurate

---

## Verification Commands

```bash
# Check entitlements in built app
codesign -d --entitlements - Pulse.app

# Verify Info.plist keys
/usr/libexec/PlistBuddy -c "Print :NSAppleEventsUsageDescription" Pulse.app/Contents/Info.plist

# Check hardened runtime
codesign -dv --verbose=4 Pulse.app | grep runtime
```

---

*Audit completed: March 27, 2026*  
*Next review: Before each major release*
