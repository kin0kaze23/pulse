# Pulse Distribution Guide

> Complete guide for building, signing, and notarizing Pulse for macOS distribution

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Xcode Project Setup](#xcode-project-setup)
4. [Code Signing](#code-signing)
5. [Notarization](#notarization)
6. [Distribution Scripts](#distribution-scripts)
7. [CI/CD Integration](#cicd-integration)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required

- **Xcode 15.0+** - Download from Mac App Store
- **Apple Developer Account** - Free for development, $99/year for distribution
- **macOS 14.0+** - Deployment target

### For Distribution

- **Developer ID Application Certificate** - Required for signing
- **Apple ID with App-Specific Password** - Required for notarization
- **Team ID** - Found in Apple Developer Portal

---

## Quick Start

### 1. Set Environment Variables

```bash
# Add to ~/.zshrc or ~/.bashrc
export DEVELOPER_TEAM_ID="ABC123DEF4"
export APPLE_ID="your@email.com"
export APPLE_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password
```

### 2. Configure Export Options

```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse/scripts
# Edit ExportOptions.plist and replace YOUR_TEAM_ID_HERE with your actual Team ID
```

### 3. Build and Sign

```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse
./scripts/distribute.sh
```

### 4. Notarize

```bash
./scripts/notarize.sh
```

### 5. Staple Ticket

```bash
./scripts/staple.sh
```

---

## Xcode Project Setup

### Project Structure

```
Pulse/
├── Pulse.xcodeproj/          # Xcode project (created)
├── Pulse/
│   └── Resources/
│       ├── Info.plist        # App configuration
│       └── Pulse.entitlements # Entitlements file
├── MemoryMonitor/Sources/    # Source code
└── scripts/                  # Distribution scripts
```

### Opening in Xcode

```bash
open Pulse.xcodeproj
```

### Build Settings Configuration

The project is pre-configured with:

| Setting | Value |
|---------|-------|
| Bundle ID | `com.nugroho.pulse` |
| Deployment Target | macOS 14.0 |
| Swift Version | 5.9 |
| Code Sign Style | Automatic |
| Hardened Runtime | Enabled |

### Entitlements

Located at `Pulse/Resources/Pulse.entitlements`:

```xml
<!-- App Sandbox: Disabled for system monitoring -->
com.apple.security.app-sandbox: false

<!-- File Access -->
com.apple.security.files.user-selected.read-write: true
com.apple.security.temporary-exception.files.absolute-path.read-write: [...]

<!-- Apple Events -->
com.apple.security.temporary-exception.apple-events: true

<!-- Network -->
com.apple.security.network.client: true
com.apple.security.network.server: true
```

---

## Code Signing

### Getting Your Developer ID Certificate

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
2. Click "+" to create a new certificate
3. Select "Developer ID Application"
4. Follow the Certificate Assistant in Keychain Access
5. Download and install the certificate

### Finding Your Team ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account/#/membership)
2. Your Team ID is displayed at the top

### Creating App-Specific Password

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Go to Security → App-Specific Passwords
4. Generate a new password for "Pulse Distribution"
5. Save the password securely

### Manual Signing (Xcode)

1. Open `Pulse.xcodeproj` in Xcode
2. Select "Pulse" target
3. Go to "Signing & Capabilities"
4. Select your Team
5. Xcode will manage certificates automatically

---

## Notarization

### What is Notarization?

Apple's security service that checks your app for malicious content. Required for:
- macOS Catalina (10.15) and later
- Apps distributed outside the Mac App Store

### Notarization Requirements

- Valid Developer ID certificate
- Hardened Runtime enabled
- Proper entitlements
- No malicious content

### Notarization Process

1. **Build** - Create signed archive
2. **Export** - Export from archive
3. **Submit** - Upload to Apple notarytool
4. **Wait** - Apple reviews (usually 5-30 minutes)
5. **Staple** - Attach notarization ticket to app

### Checking Notarization Status

```bash
xcrun notarytool history --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID"
```

---

## Distribution Scripts

### distribute.sh

Builds and signs the app:

```bash
./scripts/distribute.sh
```

**Output:** `.build/distribution/export/Pulse.app`

### notarize.sh

Submits for notarization:

```bash
./scripts/notarize.sh
```

**Requires:** `APPLE_ID`, `APPLE_PASSWORD`, `DEVELOPER_TEAM_ID`

### staple.sh

Staples the notarization ticket:

```bash
./scripts/staple.sh
```

**Result:** App is ready for distribution

---

## CI/CD Integration

### GitHub Actions

See `.github/workflows/distribution.yml` for automated distribution.

### Required Secrets

| Secret | Description |
|--------|-------------|
| `DEVELOPER_ID_CERTIFICATE` | Base64-encoded certificate |
| `DEVELOPER_ID_PASSWORD` | Certificate password |
| `APPLE_ID` | Apple ID email |
| `APPLE_PASSWORD` | App-specific password |
| `DEVELOPER_TEAM_ID` | Team ID |

### Manual Trigger

Distribution workflow can be triggered manually:
1. Go to Actions → Distribution
2. Click "Run workflow"
3. Select branch/tag
4. Click "Run workflow"

---

## Troubleshooting

### "No signing certificate found"

**Solution:**
1. Ensure Developer ID certificate is installed in Keychain
2. Select team in Xcode → Signing & Capabilities
3. Run: `security find-identity -v -p codesigning`

### "Notarization rejected"

**Common causes:**
- Missing hardened runtime entitlements
- Code signature issues
- Malicious content detected

**Solution:**
```bash
# Check entitlements
codesign -d --entitlements - Pulse.app

# Verify signature
codesign -dv --verbose=4 Pulse.app

# Check for issues
spctl -a -v Pulse.app
```

### "App will damage your computer"

**Cause:** Gatekeeper blocking unsigned app

**Solution:**
1. Ensure app is signed and notarized
2. Staple the ticket: `xcrun stapler staple Pulse.app`
3. Verify: `spctl -a -v Pulse.app`

### ExportOptions.plist errors

**Ensure:**
- Team ID is correct (no `YOUR_TEAM_ID_HERE`)
- Method is `developer-id` for distribution
- File is valid XML

---

## Verification Commands

### Check Entitlements

```bash
codesign -d --entitlements - Pulse.app
```

### Verify Signature

```bash
codesign -dv --verbose=4 Pulse.app
```

### Check Notarization

```bash
spctl -a -v Pulse.app
# Expected: "accepted" with "notarized by Developer ID"
```

### Check Hardened Runtime

```bash
codesign -dv --verbose=4 Pulse.app | grep "runtime"
# Expected: "runtime=1.0"
```

---

## Distribution Checklist

Before releasing:

- [ ] Xcode project builds without errors
- [ ] Entitlements are correct
- [ ] Code signing successful
- [ ] Notarization completed
- [ ] Ticket stapled
- [ ] App runs on clean macOS
- [ ] Gatekeeper accepts app
- [ ] All features work (permissions verified)
- [ ] README updated with download link
- [ ] Release notes written

---

*Last updated: March 27, 2026*
*Version: 1.1 (pre-release)*
