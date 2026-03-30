# Pulse Xcode Project Setup

> Instructions for creating a proper Xcode project with entitlements

---

## Why Xcode Project is Needed

Swift Package Manager (SPM) has limitations:
- ❌ No entitlements file support
- ❌ No code signing configuration
- ❌ No notarization workflow
- ❌ No App Store submission

For local development, SPM is fine. For distribution, you need Xcode.

---

## Project Creation Steps

### 1. Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. **Platform:** macOS
4. **Template:** App
5. **Product Name:** Pulse
6. **Bundle Identifier:** `com.nugroho.pulse`
7. **Interface:** SwiftUI
8. **Language:** Swift
9. **Location:** Same directory as Pulse repo

### 2. Configure Entitlements

Create `Pulse/Pulse.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Sandbox - Disabled for system monitoring -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
    
    <!-- File Access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Temporary exceptions for system directories -->
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/Library/LaunchAgents</string>
        <string>/Library/LaunchDaemons</string>
        <string>/System/Library/LaunchDaemons</string>
        <string>~/Library/LaunchAgents</string>
        <string>~/Library/Caches</string>
        <string>~/Library/Developer/Xcode</string>
        <string>~/Library/Application Support/MobileSync</string>
    </array>
    
    <!-- Network Access -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

### 3. Configure Signing

1. Select Pulse project in navigator
2. Select "Pulse" target
3. **Signing & Capabilities** tab
4. **Team:** Select your Apple Developer account (or "None" for local)
5. **Signing Certificate:** Automatic
6. **Provisioning Profile:** Automatic

### 4. Add Info.plist Keys

Ensure `Info.plist` has:

```xml
<key>LSUIElement</key>
<true/>

<key>NSAppleEventsUsageDescription</key>
<string>Pulse uses Apple Events to identify running applications for system monitoring.</string>

<key>NSAppleScriptUsageDescription</key>
<string>Pulse uses AppleScript to count browser tabs and manage applications.</string>

<key>NSAccessibilityUsageDescription</key>
<string>Pulse requests Accessibility permission to detect apps with keyboard monitoring capabilities.</string>

<key>NSSystemAdministrationUsageDescription</key>
<string>Pulse needs Full Disk Access to scan system directories for security threats.</string>
```

### 5. Configure Build Phases

1. **Build Phases** tab
2. **Link Binary With Libraries:**
   - `IOKit.framework`
   - `SystemConfiguration.framework`
   - `UserNotifications.framework`

### 6. Set Deployment Target

- **Deployment Target:** macOS 14.0
- **Swift Version:** Swift 5

---

## Build Commands

### Debug (Development)

```bash
xcodebuild -project Pulse.xcodeproj \
  -scheme Pulse \
  -configuration Debug \
  -derivedDataPath .build \
  build
```

### Release (Distribution)

```bash
xcodebuild -project Pulse.xcodeproj \
  -scheme Pulse \
  -configuration Release \
  -archivePath .build/Pulse.xcarchive \
  archive
```

### Export for Distribution

```bash
xcodebuild -exportArchive \
  -archivePath .build/Pulse.xcarchive \
  -exportPath .build/export \
  -exportOptionsPulse.plist
```

---

## Code Signing for Distribution

### 1. Get Developer ID Certificate

1. Apple Developer Portal → Certificates
2. Create "Developer ID Application" certificate
3. Download and install in Keychain

### 2. Configure Export Options

Create `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

### 3. Sign and Notarize

```bash
# Export from archive
xcodebuild -exportArchive \
  -archivePath .build/Pulse.xcarchive \
  -exportPath .build/export \
  -exportOptionsPlist ExportOptions.plist

# Notarize
xcrun notarytool submit .build/export/Pulse.app \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple ticket
xcrun stapler staple .build/export/Pulse.app
```

---

## Testing with Entitlements

### Check Entitlements

```bash
codesign -d --entitlements - .build/export/Pulse.app
```

### Verify Signature

```bash
codesign -dv --verbose=4 .build/export/Pulse.app
```

### Check Notarization

```bash
spctl -a -v .build/export/Pulse.app
```

---

## Migration from SPM

### Keep Both Projects

- **SPM:** Continue using for quick iteration and CI
- **Xcode:** Use for distribution builds

### Sync Changes

Ensure these stay in sync:
- `Package.swift` dependencies
- `Pulse.entitlements`
- `Info.plist` keys
- Source files (should auto-sync)

---

## Troubleshooting

### "Entitlements file not found"

Ensure entitlements file is:
1. In project directory
2. Added to target (Build Phases → Copy Bundle Resources)
3. Referenced correctly in Build Settings

### "Code signing failed"

Check:
1. Certificate is installed in Keychain
2. Team is selected in Signing & Capabilities
3. Provisioning profile is valid

### "Notarization rejected"

Common issues:
1. Missing hardened runtime entitlements
2. Incorrect bundle identifier
3. Expired certificate

---

*Last updated: March 27, 2026*
