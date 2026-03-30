# Contributing to Pulse

> Guidelines for contributing to Pulse

---

## Welcome!

Thanks for considering contributing to Pulse! This document provides guidelines for contributing.

---

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Prioritize user safety and privacy
- Document limitations honestly

---

## What We Need Help With

### High Priority

- [ ] **Xcode project setup** — Create proper Xcode project with entitlements
- [ ] **Notarization workflow** — Automate code signing and notarization
- [ ] **Permission diagnostics screen** — In-app UI showing permission status
- [ ] **Historical charts** — Integrate Swift Charts for metric history
- [ ] **Disk treemap** — Visual disk usage breakdown

### Medium Priority

- [ ] **Test coverage** — Add tests for monitoring services
- [ ] **Documentation** — Improve inline code comments
- [ ] **Accessibility** — VoiceOver support improvements
- [ ] **Localization** — i18n infrastructure

### Low Priority

- [ ] **More cleanup profiles** — Additional developer tools
- [ ] **Custom themes** — User-configurable colors
- [ ] **Menu bar customization** — More display options

---

## How to Contribute

### 1. Fork and Clone

```bash
git clone https://github.com/YOUR_USERNAME/pulse.git
cd pulse
```

### 2. Set Up Development Environment

```bash
# Build with Swift Package Manager
swift build

# Run tests
swift test

# Open in Xcode (optional)
open Package.swift
```

### 3. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

### 4. Make Changes

Follow the coding conventions below.

### 5. Test Your Changes

```bash
# Build
swift build

# Run tests
swift test --filter YourTestSuite

# Run the app
swift run Pulse
```

### 6. Submit a Pull Request

1. Push to your fork
2. Open a PR from your branch
3. Fill out the PR template
4. Wait for review

---

## Coding Conventions

### Swift Style

- **Indentation:** 4 spaces
- **Naming:** PascalCase for types, camelCase for variables
- **Access control:** Explicit (`private`, `fileprivate`, `public`)
- **Optionals:** Prefer `if let` over `guard` for simple cases

### Example

```swift
/// Monitors system-wide memory statistics
class SystemMemoryMonitor: ObservableObject {
    static let shared = SystemMemoryMonitor()
    
    @Published var currentMemory: SystemMemoryInfo?
    @Published var pressureLevel: MemoryPressureLevel = .normal
    
    private var timer: Timer?
    private let maxHistoryEntries = 600
    
    private init() {}
    
    func startMonitoring(interval: Double = 2.0) {
        // Implementation
    }
}
```

### Documentation

- Document all public APIs with `///` comments
- Include parameter descriptions
- Include return value descriptions
- Note side effects and threading behavior

### Example

```swift
/// Safely delete a cache directory with validation.
/// - Parameter path: The path to delete (tilde-expanded)
/// - Returns: Size freed in MB, or 0 if deletion failed
/// - Note: This function validates the path against protected locations
/// - Warning: Deletions are permanent - no undo available
private func cleanPath(_ path: String) -> Double {
    // Implementation
}
```

---

## Testing Requirements

### Unit Tests

All new features should include unit tests:

```swift
final class YourFeatureTests: XCTestCase {
    func testExpectedBehavior() {
        // Arrange
        let service = YourService()
        
        // Act
        let result = service.doSomething()
        
        // Assert
        XCTAssertEqual(result, expectedValue)
    }
}
```

### Safety Tests

For any destructive operation, add safety tests:

```swift
func testProtectedPathsCannotBeDeleted() {
    let protectedPaths = ["/System", "/bin", "/usr"]
    
    for path in protectedPaths {
        XCTAssertFalse(isPathSafeToDelete(path))
    }
}
```

### UI Tests (TODO)

Currently no UI tests exist. This is a gap in test coverage.

---

## Pull Request Guidelines

### Before Submitting

- [ ] Code builds without warnings
- [ ] Tests pass
- [ ] New code has inline documentation
- [ ] Changes match existing code style
- [ ] No secrets or credentials in code
- [ ] No machine-specific paths

### PR Description

Use the PR template and include:

- What problem this solves
- How you tested it
- Any limitations or caveats
- Screenshots if UI changed

### Review Process

1. Maintainer reviews code
2. Automated checks run (build, tests)
3. Feedback provided (if any)
4. Changes requested are addressed
5. PR is merged

---

## Issue Guidelines

### Before Opening an Issue

- [ ] Search existing issues (open and closed)
- [ ] Check CAPABILITY_MATRIX.md for known limitations
- [ ] Check LIMITATIONS.md for expected behavior
- [ ] Try latest version from main branch

### Bug Reports

Include:

- macOS version
- Pulse version (commit hash)
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/logs if applicable

### Feature Requests

Include:

- Problem you're trying to solve
- Proposed solution
- Alternatives considered
- Why this belongs in Pulse (vs a plugin)

---

## Security Considerations

### Do Not Submit

- API keys or credentials
- Personal data or telemetry
- Machine-specific paths
- Hardcoded secrets

### Security Bugs

Report security issues via email (see [SECURITY.md](SECURITY.md)), not public issues.

---

## Release Process

### Version Numbering

Pulse uses semantic versioning:

- `MAJOR.MINOR.PATCH` (e.g., 1.1.0)
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

### Release Checklist

- [ ] Update version in Info.plist
- [ ] Update CHANGELOG.md
- [ ] Tag release on GitHub
- [ ] Build release binary
- [ ] Notarize (if distributing)
- [ ] Publish release notes

---

## Questions?

- **General questions:** Open a Discussion
- **Bug reports:** Open an Issue
- **Security issues:** Email (see SECURITY.md)
- **Contrib questions:** Comment on relevant issue

---

## Thank You!

Your contributions make Pulse better for everyone. We appreciate your time and effort!

---

*Last updated: March 27, 2026*
