# Security Policy

> Security guidelines for Pulse users and contributors

---

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.1.x (pre-release) | ✅ Yes |
| 1.0.x | ⚠️ Best effort |
| < 1.0 | ❌ No |

---

## Reporting a Vulnerability

**Do not report security vulnerabilities via public GitHub issues.**

### How to Report

Email: [your-email@example.com] (TODO: Set up dedicated security email)

Include:
- Description of the vulnerability
- Steps to reproduce
- Impact assessment
- Suggested fix (if any)
- Your GitHub username (for credit)

### Response Time

- **Initial response:** Within 48 hours
- **Status update:** Within 1 week
- **Fix timeline:** Depends on severity (see below)

### Severity Levels

| Severity | Response | Fix Timeline |
|----------|----------|--------------|
| Critical | Immediate | 24-48 hours |
| High | 24 hours | 1 week |
| Medium | 48 hours | 2 weeks |
| Low | 1 week | Next release |

---

## Security Architecture

### What Pulse Does With Permissions

| Permission | What It Accesses | What It Does NOT Do |
|------------|------------------|---------------------|
| **Full Disk Access** | File sizes, directory contents | Does NOT read file contents |
| **Accessibility** | Check if apps have accessibility permission | Does NOT record keyboard/mouse |
| **Apple Events** | List running applications | Does NOT control other apps |
| **Notifications** | Show alerts to user | Does NOT send data externally |

### Data Handling

**Pulse does NOT:**
- Collect telemetry
- Send data to external servers
- Store personal information
- Track user behavior
- Use analytics

**Pulse DOES:**
- Read system metrics (memory, CPU, disk)
- Scan file paths (not contents)
- Store settings in UserDefaults
- Cache app icons temporarily

---

## Known Security Limitations

### 1. Keylogger Detection is Heuristic

**Issue:** Pulse cannot definitively detect keyloggers.

**Why:** macOS TCC (Transparency, Consent, and Control) protects accessibility permission data.

**Impact:** False negatives (keyloggers not detected) and false positives (safe apps flagged).

**Mitigation:** 
- Clearly documented as heuristic in UI
- Recommend dedicated security tools
- Show "Limited detection" warning without FDA

### 2. Cleanup Operations Are Permanent

**Issue:** Deleted files cannot be recovered.

**Why:** Uses `FileManager.removeItem()` which bypasses Trash.

**Impact:** Accidental deletion could cause data loss.

**Mitigation:**
- Path validation (protected paths blocked)
- In-use file detection
- Size limits (100GB max)
- Preview before deletion
- Clear warnings in UI

### 3. No Code Signing Verification

**Issue:** Security scanner doesn't verify code signatures.

**Why:** `codesign` verification is slow and was disabled for performance.

**Impact:** Cannot distinguish signed vs unsigned binaries.

**Mitigation:**
- Documented limitation
- CodeSignVerifier.swift exists but not integrated
- Future: Re-enable with caching

### 4. Entitlements Not Configured for Distribution

**Issue:** SPM build doesn't include entitlements.

**Why:** Swift Package Manager doesn't support entitlements.

**Impact:** 
- Full Disk Access must be granted manually
- Cannot distribute via App Store without Xcode project

**Mitigation:**
- Xcode project setup documented
- Manual FDA grant instructions provided

---

## Threat Model

### What Pulse Protects Against

- ✅ Accidental deletion of system files
- ✅ Killing critical system processes
- ✅ Cleanup of in-use files
- ✅ Unauthorized persistence (via scanner)

### What Pulse Does NOT Protect Against

- ❌ Malware installation
- ❌ Phishing attacks
- ❌ Network-based threats
- ❌ Zero-day exploits
- ❌ Hardware keyloggers

---

## Security Best Practices for Users

### Before Using Pulse

1. **Backup your Mac** — Time Machine or other backup solution
2. **Review cleanup preview** — Check what will be deleted
3. **Grant minimal permissions** — Only enable what you need
4. **Read warnings** — Pay attention to confirmation dialogs

### Recommended Permissions

| Permission | Recommended? | Why |
|------------|--------------|-----|
| Full Disk Access | Optional | Enables security scanning |
| Accessibility | Optional | Enables keylogger detection |
| Notifications | Optional | Enables memory alerts |
| Apple Events | Optional | Enables Safari tab count |

**Minimum viable:** No permissions required for basic monitoring.

---

## Security Best Practices for Contributors

### Do NOT Submit

- [ ] API keys or credentials
- [ ] Personal access tokens
- [ ] Private certificates
- [ ] Internal URLs
- [ ] User data or telemetry
- [ ] Machine-specific paths

### DO Include

- [x] Input validation for user-provided paths
- [x] Error handling for file operations
- [x] Clear documentation of limitations
- [x] Tests for safety-critical code
- [x] Inline comments explaining security decisions

### Code Review Checklist

- [ ] No hardcoded secrets
- [ ] Paths are validated before use
- [ ] Destructive operations have safety checks
- [ ] Permissions are requested (not assumed)
- [ ] Errors are logged (not silently swallowed)
- [ ] User data is not collected

---

## Incident Response

### If a Vulnerability is Found

1. **Reporter submits** via secure channel
2. **Maintainer acknowledges** within 48 hours
3. **Fix is developed** in private branch
4. **Fix is tested** thoroughly
5. **Release is published** with security advisory
6. **Credit is given** to reporter (if desired)

### Post-Incident

- Publish security advisory on GitHub
- Update SECURITY.md with lessons learned
- Review similar code for same vulnerability
- Add tests to prevent regression

---

## Third-Party Dependencies

Pulse has **zero third-party dependencies**.

All code is either:
- Written for Pulse
- Part of Apple's frameworks

This reduces supply chain attack surface.

---

## Contact

- **Security reports:** [security@pulse-app.example.com] (TODO)
- **General questions:** GitHub Discussions
- **Bug reports:** GitHub Issues (non-security only)

---

## Acknowledgments

Thanks to these security researchers for reporting vulnerabilities:

- (None yet — be the first!)

---

*Last updated: March 27, 2026*
*Version: 1.1 (pre-release)*
