# Plan: Permission Trust Loop Improvements

> **Objective:** Make permissions accurate, self-updating, and user-friendly from first launch through post-grant verification.

**Created:** 2026-03-27  
**Status:** PENDING USER REVIEW  
**Complexity:** 8 (multi-file, user-facing UX, state management, trust-critical)

---

## Success Criteria (Definition of Done)

1. ✅ **Auto-refresh:** Permission status updates automatically when user returns from System Settings
2. ✅ **Onboarding:** First-run flow explains why permissions are needed with feature impact
3. ✅ **Degraded-state UX:** Clear messaging in affected views when permissions missing
4. ✅ **Apple Events verified:** No longer "assumed granted" — actual verification or honest "Unknown"
5. ✅ **FDA honesty:** Shows "Unknown / Needs verification" rather than misleading status
6. ✅ **Build passes:** `swift build` successful, all tests pass
7. ✅ **Manual verification:** Onboarding appears, status refreshes, degraded states visible

---

## Touch List

| File | Change | Reason |
|------|--------|--------|
| `PermissionsService.swift` | Modify | Add auto-refresh observer, fix Apple Events check, add verification states |
| `PermissionsDiagnosticsView.swift` | Modify | Update UI for new status states, add verification badges |
| `App.swift` | Modify | Add NSWorkspace notification observer in AppDelegate |
| `SecurityView.swift` | Modify | Add degraded-state messaging for missing permissions |
| `SecurityScanner.swift` | Modify | Add permission-dependent feature status |
| `OnboardingPermissionView.swift` | **NEW** | First-run onboarding flow |
| `AppSettings.swift` | Modify | Add `hasSeenPermissionOnboarding` flag |
| `DashboardView.swift` | Modify | Trigger onboarding on first launch |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Apple Events check requires actual event** | May need to send harmless event to verify | Send `Finder` version request, catch error, timeout after 2s |
| **FDA check unreliable** | TCC path may be readable but access incomplete | Add secondary verification, show "Unknown" if ambiguous |
| **Onboarding blocks first launch** | Poor UX if modal is intrusive | Show as non-blocking overlay, allow "Skip" |
| **Entitlements not integrated** | SPM doesn't support entitlements | Document limitation, show "Requires Xcode build" in UI |
| **Notification permission async** | Check may timeout | Keep existing 1s timeout, show "Unknown" on timeout |

---

## Phases

### Phase 1: Auto-Refresh Permission Status
**Entry:** Current state  
**Exit:** Permission status updates when app becomes active

**Tasks:**
1. Add `NSWorkspace.didActivateApplicationNotification` observer in `AppDelegate`
2. Add `checkAllPermissions()` call when app returns to foreground
3. Add toast notification when permission status changes
4. Update `PermissionsService` to detect and publish status changes

**Files:** `App.swift`, `PermissionsService.swift`

---

### Phase 2: First-Run Onboarding Flow
**Entry:** Phase 1 complete  
**Exit:** Onboarding appears on first launch, explains permissions

**Tasks:**
1. Add `hasSeenPermissionOnboarding` to `AppSettings`
2. Create `OnboardingPermissionView` with:
   - Welcome screen explaining Pulse needs permissions
   - Per-permission explanation with feature impact
   - "Grant All" and "Skip" options
   - Clear messaging that app works partially without some permissions
3. Trigger onboarding in `DashboardView.onAppear` if first launch
4. Dismiss onboarding sets `hasSeenPermissionOnboarding = true`

**Files:** `AppSettings.swift`, `OnboardingPermissionView.swift` (NEW), `DashboardView.swift`

---

### Phase 3: Degraded-State UX
**Entry:** Phase 2 complete  
**Exit:** All affected views show honest degraded-state messaging

**Tasks:**
1. **SecurityView:**
   - If FDA missing: "Security scan limited — cannot read system directories"
   - If Accessibility missing: "Keylogger detection unavailable"
   - If Notifications missing: "Alerts disabled — enable in System Settings"
   - If Apple Events missing: "Browser tab counting unavailable"
2. **SecurityScanner:**
   - Add `permissionDependentFeatures` computed property
   - Return list of features with status (available/limited/unavailable)
3. Update `PermissionsDiagnosticsView` to show feature status inline

**Files:** `SecurityView.swift`, `SecurityScanner.swift`, `PermissionsDiagnosticsView.swift`

---

### Phase 4: Fix Permission Assumptions
**Entry:** Phase 3 complete  
**Exit:** All permissions verified or honestly marked "Unknown"

**Tasks:**
1. **Apple Events:**
   - Send harmless Apple Event to Finder (`version` property)
   - Catch error → status = "Missing"
   - Timeout after 2s → status = "Unknown"
   - Success → status = "Granted"
2. **Full Disk Access:**
   - Keep existing TCC path check
   - Add secondary check: try reading `/Library/Logs` (also protected)
   - If checks disagree → status = "Unknown / Needs verification"
   - Update UI to explain verification limitation honestly
3. Update `PermissionInfo` model to support "verification_pending" state

**Files:** `PermissionsService.swift`, `PermissionsDiagnosticsView.swift`

---

## Architecture Decisions

### Decision 1: Auto-Refresh Mechanism
**Chosen:** `NSWorkspace.didActivateApplicationNotification` observer in `AppDelegate`  
**Why:** System-provided, reliable, fires when user returns from System Settings  
**Alternatives considered:**
- Polling every 5s → ❌ Battery drain, wasteful
- `ScenePhase` → ❌ Not available in SwiftUI macOS menu bar apps
- File watcher on TCC database → ❌ Unreliable, privacy concerns

**Decision rule:** Prefer system-provided notifications over custom polling for battery-conscious macOS apps.

---

### Decision 2: Onboarding Timing
**Chosen:** Non-blocking overlay on first launch, dismissable with "Skip"  
**Why:** Respects user autonomy, doesn't block app usage, reduces friction  
**Alternatives considered:**
- Blocking modal before dashboard → ❌ Poor UX, feels coercive
- Settings-only (no onboarding) → ❌ Users miss important context
- Multi-step wizard → ❌ Too heavy for permissions explanation

**Decision rule:** Prefer lightweight, dismissable onboarding for utility apps where core functionality works without permissions.

---

### Decision 3: Apple Events Verification
**Chosen:** Send harmless `Finder` version request with 2s timeout  
**Why:** Actual verification > assumption, timeout prevents hangs  
**Alternatives considered:**
- Keep "assumed granted" → ❌ Misleading, breaks trust
- Check Automation list in System Settings → ❌ Requires FDA, circular dependency
- Wait for on-demand prompt → ❌ Too late, user confused why feature failed

**Decision rule:** Prefer active verification with timeout for permissions that can't be checked directly.

---

### Decision 4: FDA Verification Honesty
**Chosen:** Multi-check with "Unknown / Needs verification" fallback  
**Why:** Acknowledges limitation, doesn't mislead user  
**Alternatives considered:**
- Single TCC path check → ❌ May give false positive
- Claim "Cannot verify" always → ❌ Defeatist, unhelpful
- Require Endpoint Security framework → ❌ Out of scope for this pass

**Decision rule:** Prefer honest uncertainty over false confidence for security-critical permissions.

---

## Verification Plan

### Automated
```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse
swift build
swift test
```

### Manual (Browser/App Verification)
1. **First Launch:**
   - Reset app state (delete UserDefaults)
   - Launch Pulse
   - Verify onboarding appears
   - Verify "Skip" works
   - Verify "Grant All" opens System Settings

2. **Auto-Refresh:**
   - Open Settings → Privacy & Security
   - Grant Full Disk Access to Pulse
   - Return to Pulse
   - Verify status updates within 2s (no manual refresh needed)
   - Verify toast notification appears

3. **Degraded States:**
   - Revoke all permissions
   - Open Security tab
   - Verify: "Security scan limited" message visible
   - Verify: "Keylogger detection unavailable" visible
   - Verify: "Browser tab counting unavailable" visible

4. **Permission Diagnostics:**
   - Open Settings → Permissions
   - Verify each permission shows correct status
   - Verify Apple Events shows "Unknown" if unverified
   - Verify FDA shows "Unknown" if checks disagree

---

## Completion Evidence

**To be filled after implementation:**
- [ ] Build output
- [ ] Test results
- [ ] Screenshot: Onboarding flow
- [ ] Screenshot: Auto-refresh toast
- [ ] Screenshot: Degraded-state messaging
- [ ] Screenshot: Permission diagnostics with new states

---

## Remaining Trust Gaps (Post-Implementation)

**After this pass, these gaps will remain:**
1. **Endpoint Security framework** not implemented (out of scope)
2. **Real-time permission revocation detection** still limited (OS limitation)
3. **Entitlements integration** requires Xcode project (SPM limitation)
4. **Notification permission granularity** (alert vs badge vs sound) not implemented

**These are acceptable for V1.1** — documented for future releases.

---

## Approval

**User approval required before implementation begins.**

Reply "Proceed" to start implementation, or request changes to the plan.
