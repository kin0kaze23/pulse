# Plan: Xcode Distribution Setup for Pulse

> **Objective:** Prepare Pulse for real macOS distribution by moving from SPM-only to proper Xcode-based shipping path with entitlements, signing, and notarization.

**Created:** 2026-03-27  
**Status:** PENDING USER REVIEW  
**Complexity:** 9 (infrastructure, signing, distribution-critical)

---

## Success Criteria (Definition of Done)

1. ✅ **Xcode project created** — `Pulse.xcodeproj` exists and opens in Xcode
2. ✅ **Entitlements integrated** — `Pulse.entitlements` wired into target build settings
3. ✅ **Signing configured** — Debug and Release configurations documented
4. ✅ **Notarization prepared** — Scripts and checklist for notarization workflow
5. ✅ **CI/CD updated** — GitHub Actions workflow supports distribution builds
6. ✅ **Permission audit complete** — Features aligned with entitlements
7. ✅ **Build verification** — `xcodebuild` succeeds in Debug and Release
8. ✅ **Distribution checklist** — Clear list of remaining steps before public release

---

## Touch List

| File | Change | Reason |
|------|--------|--------|
| `Pulse.xcodeproj/` | **NEW** | Xcode project structure |
| `Pulse.xcworkspace/` | **NEW** | Xcode workspace (if needed) |
| `Pulse.entitlements` | Verify/Update | Ensure all required entitlements declared |
| `ExportOptions.plist` | **NEW** | Export configuration for distribution |
| `scripts/distribute.sh` | **NEW** | Distribution build script |
| `scripts/notarize.sh` | **NEW** | Notarization script |
| `docs/DISTRIBUTION.md` | **NEW** | Complete distribution guide |
| `docs/SIGNING_CHECKLIST.md` | **NEW** | Signing and notarization checklist |
| `.github/workflows/distribution.yml` | **NEW** | CI workflow for distribution |
| `PERMISSION_ENTITLEMENTS_AUDIT.md` | **NEW** | Audit of permission-dependent features |
| `NOW.md` | Update | Distribution setup status |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Xcode project creation is manual** | Cannot fully automate | Provide detailed scripts + manual steps documentation |
| **Signing requires Developer ID certificate** | User-specific, not commitable | Document process, use placeholders in templates |
| **Notarization requires Apple ID credentials** | Cannot store in repo | Use environment variables, keychain, document setup |
| **Entitlements may need adjustment** | Temporary exceptions may change | Audit against actual feature requirements |
| **SPM dependencies may not link** | Frameworks need manual linking | Document required frameworks, verify in build |

---

## Phases

### Phase 1: Xcode Project Creation
**Entry:** Current state (SPM only)  
**Exit:** Xcode project exists and builds

**Tasks:**
1. Create `Pulse.xcodeproj` structure manually (XML format)
2. Configure target with:
   - macOS App type
   - Deployment target: macOS 14.0
   - Swift version: 5.9
3. Add source files from `MemoryMonitor/Sources/`
4. Link required frameworks:
   - IOKit
   - SystemConfiguration
   - UserNotifications
   - AppKit
   - SwiftUI
5. Configure Info.plist with permission descriptions
6. Set `LSUIElement = true` for menu bar app

**Files:** `Pulse.xcodeproj/project.pbxproj` (NEW), `Info.plist` (verify)

---

### Phase 2: Entitlements Integration
**Entry:** Phase 1 complete  
**Exit:** Entitlements wired into target

**Tasks:**
1. Verify `Pulse.entitlements` contains all required entitlements
2. Add entitlements file to Xcode target
3. Configure build settings:
   - `CODE_SIGN_ENTITLEMENTS = Pulse/Pulse.entitlements`
4. Audit entitlements against actual feature requirements
5. Document each entitlement and why it's needed

**Files:** `Pulse.entitlements` (verify), `Pulse.xcodeproj/project.pbxproj` (update)

---

### Phase 3: Signing Configuration
**Entry:** Phase 2 complete  
**Exit:** Signing documented and reproducible

**Tasks:**
1. Create `ExportOptions.plist` for distribution
2. Document signing requirements:
   - Developer ID Application certificate
   - Team ID configuration
   - Provisioning profile (automatic for Mac)
3. Create signing checklist for users
4. Document Debug vs Release signing differences

**Files:** `ExportOptions.plist` (NEW), `docs/SIGNING_CHECKLIST.md` (NEW)

---

### Phase 4: Notarization Preparation
**Entry:** Phase 3 complete  
**Exit:** Notarization workflow ready

**Tasks:**
1. Create `scripts/notarize.sh` script
2. Document notarization requirements:
   - Apple ID
   - App-specific password
   - Team ID
3. Create stapling script
4. Document troubleshooting for common notarization failures

**Files:** `scripts/notarize.sh` (NEW), `scripts/staple.sh` (NEW), `docs/DISTRIBUTION.md` (NEW)

---

### Phase 5: Distribution Script
**Entry:** Phase 4 complete  
**Exit:** One-command distribution build

**Tasks:**
1. Create `scripts/distribute.sh` that:
   - Builds archive with xcodebuild
   - Exports with ExportOptions.plist
   - Runs notarization
   - Staples ticket
   - Verifies signature
2. Make script idempotent and safe
3. Document environment variables needed

**Files:** `scripts/distribute.sh` (NEW)

---

### Phase 6: CI/CD Integration
**Entry:** Phase 5 complete  
**Exit:** GitHub Actions supports distribution

**Tasks:**
1. Create `.github/workflows/distribution.yml`
2. Configure for:
   - Manual trigger (workflow_dispatch)
   - Release tag trigger
3. Use environment variables for secrets:
   - DEVELOPER_ID_CERTIFICATE
   - APPLE_ID
   - APPLE_TEAM_ID
   - APPLE_PASSWORD
4. Build, sign, notarize, upload artifact

**Files:** `.github/workflows/distribution.yml` (NEW)

---

### Phase 7: Permission/Entitlements Audit
**Entry:** Phase 6 complete  
**Exit:** Features aligned with entitlements

**Tasks:**
1. Audit each permission-dependent feature:
   - Full Disk Access → Security scanner, cleanup
   - Accessibility → Keylogger detection
   - Apple Events → Browser tab counting
   - Notifications → Alerts
2. Verify each has corresponding entitlement or Info.plist key
3. Document any gaps or mismatches
4. Update entitlements if needed

**Files:** `PERMISSION_ENTITLEMENTS_AUDIT.md` (NEW)

---

### Phase 8: Verification
**Entry:** Phase 7 complete  
**Exit:** Build verified

**Tasks:**
1. Run `xcodebuild -scheme Pulse -configuration Debug build`
2. Run `xcodebuild -scheme Pulse -configuration Release archive`
3. Verify entitlements: `codesign -d --entitlements - Pulse.app`
4. Verify signature: `codesign -dv --verbose=4 Pulse.app`
5. Document any issues and fixes

**Commands:** xcodebuild, codesign verification

---

## Architecture Decisions

### Decision 1: Xcode Project Structure
**Chosen:** Manual project.pbxproj creation with documented structure  
**Why:** SPM cannot produce signed/notarized apps; Xcode project required for distribution  
**Alternatives considered:**
- Keep SPM only → ❌ Cannot sign or notarize
- Use Tuist or XcodeGen → ❌ Adds complexity, learning curve
- Manual Xcode project → ✅ Direct control, well-documented

**Decision rule:** Prefer direct Xcode project for macOS distribution where signing is mandatory.

---

### Decision 2: Entitlements Strategy
**Chosen:** Keep existing `Pulse.entitlements` with App Sandbox disabled  
**Why:** Pulse requires system-level access incompatible with sandbox; temporary exceptions needed  
**Alternatives considered:**
- Enable App Sandbox → ❌ Would break security scanning, system monitoring
- Partial sandbox → ❌ Complex, still breaks key features
- No sandbox (current) → ✅ Honest about requirements, works

**Decision rule:** Prefer honest entitlements over forced sandboxing that breaks core features.

---

### Decision 3: Distribution Script Location
**Chosen:** `scripts/` directory at repo root  
**Why:** Clear separation from source code, easy to find, standard convention  
**Alternatives considered:**
- `.github/scripts/` → ❌ Tied to GitHub, not general
- `docs/scripts/` → ❌ Confusing with documentation
- Root level → ❌ Clutters root directory
- `scripts/` → ✅ Standard, clear purpose

**Decision rule:** Prefer `scripts/` directory for build/distribution automation.

---

### Decision 4: CI/CD Secrets Management
**Chosen:** Environment variables via GitHub Secrets  
**Why:** Standard practice, secure, documented by GitHub  
**Alternatives considered:**
- Encrypted files in repo → ❌ Complex, key management
- External secret manager → ❌ Overkill for single repo
- GitHub Secrets → ✅ Built-in, secure, standard

**Decision rule:** Use GitHub Secrets for all distribution credentials.

---

## Verification Plan

### Automated
```bash
# Debug build
xcodebuild -project Pulse.xcodeproj \
  -scheme Pulse \
  -configuration Debug \
  -derivedDataPath .build \
  build

# Release archive
xcodebuild -project Pulse.xcodeproj \
  -scheme Pulse \
  -configuration Release \
  -archivePath .build/Pulse.xcarchive \
  archive

# Verify entitlements
codesign -d --entitlements - .build/Pulse.xcarchive/Products/Applications/Pulse.app

# Verify signature
codesign -dv --verbose=4 .build/Pulse.xcarchive/Products/Applications/Pulse.app
```

### Manual
1. Open `Pulse.xcodeproj` in Xcode → Verify no errors
2. Build in Xcode (⌘B) → Verify success
3. Archive (Product → Archive) → Verify success
4. Export using ExportOptions.plist → Verify app runs
5. Run notarization script → Verify success
6. Staple ticket → Verify with `spctl -a -v`

---

## Completion Evidence

**To be filled after implementation:**
- [ ] Xcode project opens without errors
- [ ] Debug build succeeds
- [ ] Release archive succeeds
- [ ] Entitlements verification output
- [ ] Signature verification output
- [ ] Distribution script tested
- [ ] CI workflow validated

---

## Remaining Blockers Before Public Release

**After this pass, these will remain:**
1. **Developer ID certificate** — User must obtain from Apple Developer Portal
2. **Notarization credentials** — User must create app-specific password
3. **App icon finalization** — Current icon may need professional design
4. **Screenshots for README** — Need actual app screenshots
5. **Website/landing page** — Optional but recommended for distribution
6. **Sparkle auto-update setup** — Optional for V1, recommended for V1.1+

**These are user-specific setup steps that cannot be pre-configured in the repo.**

---

## Approval

**User approval required before implementation begins.**

Reply "Proceed" to start implementation, or request changes to the plan.
