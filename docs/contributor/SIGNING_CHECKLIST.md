# Signing & Notarization Checklist

> Step-by-step checklist for signing and notarizing Pulse

---

## Phase 1: Apple Developer Setup (One-Time)

### 1.1 Enroll in Apple Developer Program

- [ ] Go to [developer.apple.com](https://developer.apple.com)
- [ ] Enroll in Apple Developer Program ($99/year)
- [ ] Wait for approval (usually immediate for individuals)

### 1.2 Create Developer ID Certificate

- [ ] Open Keychain Access on your Mac
- [ ] Menu: Keychain Access → Certificate Assistant → Request a Certificate
- [ ] Enter your email, select "Saved to disk"
- [ ] Go to [Certificates Portal](https://developer.apple.com/account/resources/certificates/list)
- [ ] Click "+" → "Developer ID Application"
- [ ] Upload the CSR file from Keychain Access
- [ ] Download the certificate
- [ ] Double-click to install in Keychain Access
- [ ] Verify: `security find-identity -v -p codesigning`

### 1.3 Get Your Team ID

- [ ] Go to [Membership Portal](https://developer.apple.com/account/#/membership)
- [ ] Copy your Team ID (10 characters, e.g., `ABC123DEF4`)
- [ ] Save it in a password manager

### 1.4 Create App-Specific Password

- [ ] Go to [appleid.apple.com](https://appleid.apple.com)
- [ ] Sign in with your Apple ID
- [ ] Go to Security → App-Specific Passwords
- [ ] Click "Generate Password"
- [ ] Label: "Pulse Distribution"
- [ ] Copy the password (format: `xxxx-xxxx-xxxx-xxxx`)
- [ ] Save in password manager

---

## Phase 2: Repository Configuration

### 2.1 Configure ExportOptions.plist

- [ ] Open `scripts/ExportOptions.plist`
- [ ] Replace `YOUR_TEAM_ID_HERE` with your actual Team ID
- [ ] Verify method is `developer-id`
- [ ] Save the file
- [ ] **Do not commit** (add to .gitignore or use template)

### 2.2 Set Environment Variables

Add to `~/.zshrc` or `~/.bashrc`:

```bash
export DEVELOPER_TEAM_ID="ABC123DEF4"
export APPLE_ID="your@email.com"
export APPLE_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

- [ ] Run `source ~/.zshrc` (or restart terminal)
- [ ] Verify: `echo $DEVELOPER_TEAM_ID`

### 2.3 Verify Entitlements

- [ ] Open `Pulse/Resources/Pulse.entitlements`
- [ ] Verify all required entitlements are present
- [ ] Ensure App Sandbox is `false` (required for system monitoring)

---

## Phase 3: Build & Sign

### 3.1 Open Xcode Project

- [ ] Run: `open Pulse.xcodeproj`
- [ ] Verify project opens without errors
- [ ] Select "Pulse" target
- [ ] Go to "Signing & Capabilities"
- [ ] Verify your Team is selected
- [ ] Verify Bundle ID is `com.nugroho.pulse`

### 3.2 Build in Xcode

- [ ] Product → Scheme → Pulse
- [ ] Product → Destination → My Mac
- [ ] Product → Build (⌘B)
- [ ] Verify build succeeds

### 3.3 Build via Script

- [ ] Run: `./scripts/distribute.sh`
- [ ] Verify archive created
- [ ] Verify app exported
- [ ] Verify signature

### 3.4 Manual Verification

```bash
# Check entitlements
codesign -d --entitlements - .build/distribution/export/Pulse.app

# Verify signature
codesign -dv --verbose=4 .build/distribution/export/Pulse.app

# Check Gatekeeper
spctl -a -v .build/distribution/export/Pulse.app
```

- [ ] Entitlements match expected
- [ ] Signature is valid
- [ ] Gatekeeper accepts

---

## Phase 4: Notarization

### 4.1 Submit for Notarization

- [ ] Run: `./scripts/notarize.sh`
- [ ] Wait for completion (5-30 minutes)
- [ ] Check for "accepted" status

### 4.2 Check Notarization Status

```bash
xcrun notarytool history \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_PASSWORD" \
  --team-id "$DEVELOPER_TEAM_ID"
```

- [ ] Latest submission shows "accepted"

### 4.3 Staple Ticket

- [ ] Run: `./scripts/staple.sh`
- [ ] Verify stapling succeeded

### 4.4 Verify Notarization

```bash
spctl -a -v .build/distribution/export/Pulse.app
```

- [ ] Output includes "notarized by Developer ID"
- [ ] Output shows "accepted"

---

## Phase 5: Final Testing

### 5.1 Test on Clean Mac (Recommended)

- [ ] Use a clean macOS VM or secondary Mac
- [ ] Copy the app
- [ ] Try to open (double-click)
- [ ] Verify no Gatekeeper warnings
- [ ] Verify all features work

### 5.2 Test Permissions Flow

- [ ] Launch app fresh
- [ ] Verify onboarding appears
- [ ] Grant Full Disk Access → verify status updates
- [ ] Grant Accessibility → verify status updates
- [ ] Verify degraded-state messaging when permissions missing

### 5.3 Test Menu Bar

- [ ] Verify icon appears in menu bar
- [ ] Verify popover opens
- [ ] Verify monitoring works
- [ ] Verify quit works

---

## Phase 6: Release Preparation

### 6.1 Version Bump

- [ ] Update `MARKETING_VERSION` in project.pbxproj
- [ ] Update `CURRENT_PROJECT_VERSION` (build number)
- [ ] Update README with latest version
- [ ] Update CHANGELOG (if exists)

### 6.2 Create Release Artifact

- [ ] Zip the app: `ditto -c -k --sequesterRsrc --keepParent Pulse.app Pulse.zip`
- [ ] Verify zip contents
- [ ] Test unzip on another machine

### 6.3 Documentation

- [ ] Update README with download link
- [ ] Write release notes
- [ ] Add screenshots (if missing)
- [ ] Verify LICENSE is included

---

## Quick Reference

### Environment Variables

```bash
export DEVELOPER_TEAM_ID="ABC123DEF4"
export APPLE_ID="your@email.com"
export APPLE_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

### Build Commands

```bash
# Full distribution build
./scripts/distribute.sh

# Notarize
./scripts/notarize.sh

# Staple
./scripts/staple.sh

# Verify
spctl -a -v .build/distribution/export/Pulse.app
```

### Xcode Commands

```bash
# Open project
open Pulse.xcodeproj

# Build archive
xcodebuild -project Pulse.xcodeproj -scheme Pulse -configuration Release archive

# Export
xcodebuild -exportArchive -archivePath Pulse.xcarchive -exportPath ./export -exportOptionsPlist ../scripts/ExportOptions.plist
```

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Certificate not found | Reinstall from Keychain Access |
| Team ID wrong | Check Apple Developer Portal |
| Notarization rejected | Check hardened runtime entitlements |
| Gatekeeper blocks | Ensure ticket is stapled |
| App crashes on launch | Check console logs for code signing errors |

---

*Last updated: March 27, 2026*
