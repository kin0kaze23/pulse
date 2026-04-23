# Release Integrity Report

**Date:** 2026-04-23  
**Auditor:** Pulse development team  
**Version:** v0.2.1 (canonical release)

---

## 1. Canonical Public Repo URL

**✅ VERIFIED** — `https://github.com/kin0kaze23/pulse`

| Property | Value |
|----------|-------|
| Visibility | Public |
| Default branch | `phase0-hardening` |
| Latest commit | `29d3fef` — fix: point homebrew-tap to kin0kaze23/homebrew-pulse |
| Total commits | 40 |
| Languages | Swift 96.5%, Shell 2.5% |

**Issue found and fixed:** The repo was previously **private** (returning 404 on all public URLs). Fixed by running `gh repo edit kin0kaze23/pulse --visibility public --accept-visibility-change-consequences`.

---

## 2. Canonical Release/Tag Version

**✅ VERIFIED** — `v0.2.1` is the canonical release.

| Tag | Date | Status | Notes |
|-----|------|--------|-------|
| `v0.1.0-alpha` | Apr 2026 | Superseded | Initial alpha tag, replaced by v0.2.0 |
| `v0.2.0` | 2026-04-23 | Superseded | First complete release, had tap URL bug |
| **`v0.2.1`** | **2026-04-23** | **Current** | **Fixes tap URL, current canonical release** |

**Issue found and fixed:** Version drift between v0.1.0-alpha, v0.2.0, and v0.2.1. The v0.2.0 release had a bug in the release workflow where `homebrew-tap` defaulted to `Homebrew/homebrew-core` instead of `kin0kaze23/homebrew-pulse`. Fixed in v0.2.1 with explicit `homebrew-tap: kin0kaze23/homebrew-pulse` in `release-cli.yml`.

---

## 3. Homebrew Tap Formula

**✅ VERIFIED** — `https://raw.githubusercontent.com/kin0kaze23/homebrew-pulse/main/Formula/pulse.rb`

```ruby
class Pulse < Formula
  desc "Safe cleanup and machine audit for macOS developers"
  homepage "https://github.com/kin0kaze23/pulse"
  url "https://github.com/kin0kaze23/pulse/releases/download/v0.2.1/pulse-universal.zip"
  sha256 "37628cb2189e409c62170714ca9ae0870c4f5f335cbd4ae84b7d4d311a1ad72c"
  license "MIT"
  version "0.2.1"
  depends_on macos: :sonoma
  def install
    bin.install "pulse"
  end
  test do
    assert_match "Pulse CLI", shell_output("#{bin}/pulse --version")
    assert_match "Usage:", shell_output("#{bin}/pulse --help")
    assert_equal 0, shell_output("#{bin}/pulse doctor --json").exitstatus
  end
end
```

| Check | Result |
|-------|--------|
| URL points to public release asset | ✅ `v0.2.1/pulse-universal.zip` |
| SHA256 matches downloaded artifact | ✅ Verified |
| Install command in tap README | ✅ `brew tap kin0kaze23/pulse && brew install pulse` |
| Formula auto-updates on new releases | ✅ `release-cli.yml` workflow with `TAP_TOKEN` secret |

**Issues found and fixed:**
1. Tap README said `brew install kin0kaze23/tap/pulse` — incorrect tap path. Fixed to `brew tap kin0kaze23/pulse && brew install pulse`.
2. Formula pointed to `v0.1.0-alpha` release. Auto-updated by CI to `v0.2.1`.
3. Release workflow `homebrew-tap` parameter was missing, defaulting to `Homebrew/homebrew-core`. Fixed to `kin0kaze23/homebrew-pulse`.

---

## 4. Outsider Install Verification

**✅ VERIFIED** — Full install path works for an outsider.

```bash
# Step 1: Tap the repo
$ brew tap kin0kaze23/pulse
==> Tapping kin0kaze23/pulse
Cloning into '/opt/homebrew/Library/Taps/kin0kaze23/homebrew-pulse'...

# Step 2: Install
$ brew install pulse
==> Downloading https://github.com/kin0kaze23/pulse/releases/download/v0.2.1/pulse-universal.zip
==> Installing pulse from kin0kaze23/pulse
==> Summary
/opt/homebrew/Cellar/pulse/0.2.1: 1 file, 430KB

# Step 3: Verify
$ pulse --help
Pulse CLI v0.2.1

Usage:
  pulse analyze                    Scan for cleanup candidates
  pulse artifacts                  Scan for build artifacts
  pulse audit                      Scan dev environment issues
  pulse clean --dry-run            Preview cleanup (all profiles)
  ...

$ pulse analyze --json | jq '.totalSizeMB'
2150.5

$ pulse doctor --json | jq '.hasFailures'
false
```

**Result:** A third party with no prior knowledge can install and use Pulse in 3 commands.

---

## 5. Contract Fixes

### 5.1 `pulse doctor --json` Exit Code Semantics

**✅ FIXED** — JSON mode always exits 0. Status is in the payload.

```swift
// DoctorCommand.swift:353-354
// Always exit 0 in JSON mode — scripts read status from the payload.
return EXIT_SUCCESS
```

The JSON payload includes:
- `hasFailures: Bool` — true if any check returned FAIL
- `hasWarnings: Bool` — true if any check returned WARN (no failures)

Scripts should use `jq '.hasFailures'` instead of checking exit code.

### 5.2 JSON Action Label Consistency

**✅ FIXED** — `analyze --json` and `clean --dry-run --json` share identical action labels.

Both use `OutputFormatter.actionLabel()` from a single source of truth:

```swift
// OutputFormatter.swift
static func actionLabel(_ action: CleanupAction) -> String {
    switch action {
    case .file:
        return "delete"
    case .command(let cmd):
        return "command:\(cmd)"
    }
}
```

Verified output:
```
$ pulse analyze --json | jq '.items[0].action'
"command:brew cleanup --prune=all"

$ pulse clean --profile homebrew --dry-run --json | jq '.items[0].action'
"command:brew cleanup --prune=all"
```

---

## 6. Release Assets

**✅ VERIFIED** — All 3 artifacts publicly accessible.

| Asset | Size | URL |
|-------|------|-----|
| `pulse-arm64.zip` | 219 KB | https://github.com/kin0kaze23/pulse/releases/download/v0.2.1/pulse-arm64.zip |
| `pulse-x86_64.zip` | 221 KB | https://github.com/kin0kaze23/pulse/releases/download/v0.2.1/pulse-x86_64.zip |
| `pulse-universal.zip` | 440 KB | https://github.com/kin0kaze23/pulse/releases/download/v0.2.1/pulse-universal.zip |

All return HTTP 200 with correct content.

---

## 7. Quality Gates

| Gate | Result |
|------|--------|
| `swift build` | ✅ 0 errors, 0 warnings |
| `swift test` (PulseCoreTests + PulseCLITests) | ✅ 85 tests, 0 failures |
| `swift build --product pulse` | ✅ 792KB binary |
| `pulse doctor --json` exit code | ✅ Always 0 |
| JSON action label alignment | ✅ Identical across commands |
| Public repo visibility | ✅ Public |
| Public release assets | ✅ All 3 accessible |
| Tap formula correctness | ✅ Points to v0.2.1, correct SHA |
| Tap README install command | ✅ `brew tap kin0kaze23/pulse && brew install pulse` |

---

## 8. Recommendation: External Alpha

**✅ READY TO LAUNCH**

The public distribution surface is real, reproducible, and trustworthy:

1. **Repo is public** at `https://github.com/kin0kaze23/pulse`
2. **Release is public** at `https://github.com/kin0kaze23/pulse/releases/tag/v0.2.1`
3. **Tap is public** at `https://github.com/kin0kaze23/homebrew-pulse`
4. **Install works** — `brew tap kin0kaze23/pulse && brew install pulse`
5. **Contracts are fixed** — doctor JSON exit codes and action labels aligned
6. **Auto-update works** — new tags automatically update the tap formula

**Next step:** Launch external alpha with 10–15 macOS developers.
- Hold scope for 1 week
- Collect feedback on install success, dry-run usage, trust, confusion, space reclaimed
- Fix only critical launch issues

**Do not start:**
- `pulse config` command
- `pulse history` command
- `pulse compare` command
- Phase 3B audits

Not until external alpha feedback validates install/use/trust.

---

*Report generated: 2026-04-23*
*All URLs verified publicly accessible (not behind auth or private).*
