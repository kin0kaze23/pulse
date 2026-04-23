# Verification Gates — Pulse

## Default Profile: ui-surface

Pulse is a **Swift/macOS application** - gates differ from Node.js projects.

```bash
# Gate 1: Swift Build
xcodebuild -project Pulse.xcodeproj -scheme Pulse -configuration Debug build

# Gate 2: SwiftLint (if installed)
swiftlint || true

# Gate 3: Tests
xcodebuild test -project Pulse.xcodeproj -scheme Pulse -destination 'platform=macOS'
```

## macOS-Specific Notes

- Requires Xcode installed
- Build requires valid code signing (or use ad-hoc for local dev)
- Tests run in Xcode test navigator or via xcodebuild

## Exit Codes
- 0 = all gates passed
- 1 = gate failed (stop, report)
- 2 = command not found (report, skip)

---
Last updated: 2026-04-02