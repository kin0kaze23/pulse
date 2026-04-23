# Pulse CLI v0.2.0

**Release date:** 2026-04-23
**Tag:** v0.2.0

---

## What's New

Pulse v0.2.0 is the most complete alpha release yet — adding project artifact scanning, developer environment auditing, Homebrew tap distribution, and production-ready safety hardening.

### New Commands

| Command | Description |
|---------|-------------|
| `pulse artifacts` | Scan project directories for build artifacts (node_modules, .build, target, venv, dist, and 10 more) |
| `pulse audit` | Audit developer environment for stale simulators, orphaned Homebrew taps, dead symlinks, and old toolchains |

### New Features

- **Homebrew tap install**: `brew tap kin0kaze23/pulse && brew install pulse`
- **Auto JSON detection**: Commands auto-switch to JSON when piped (no `--json` flag needed)
- **Config file**: `~/.config/pulse/config.json` for custom scan paths, age thresholds, and exclusions
- **`--yes` / `-y` / `--force` flags**: Skip confirmation for CI/CD automation
- **Non-TTY detection**: ANSI colors disabled when output is piped
- **Git-tagged version**: `--version` reads from git tags automatically
- **Expanded artifact types**: 16 types including Next.js, Nuxt, Parcel, Elm, Go, Bun

### Safety Hardening

- **TOCTOU race condition fix**: Paths are re-validated immediately before deletion
- **Symlink guard**: Resolved symlinks are checked against protected paths before deletion
- **Tightened path validation**: `/var/folders` uses explicit allow-list instead of blanket exception
- **Swift 6 compatibility**: All public types are `Sendable`-conforming
- **Zero compiler warnings**: Clean build across all targets

### Fixed

- **Binary collision**: Fixed `pulse` vs `Pulse` filename collision on case-insensitive filesystem
- **Doctor JSON exit code**: Always exits 0 — status is in the payload
- **JSON schema alignment**: `analyze` and `clean --dry-run` share identical action labels
- **README accuracy**: Removed stale "No JSON output" limitation

---

## Safety

- **Preview-first**: Dry-run is the default
- **Confirmation required**: `--apply` requires typing "yes"
- **Protected paths**: System paths, user data, and app bundles cannot be deleted
- **Trash-first**: Files go to Trash before permanent deletion
- **TOCTOU protection**: Re-validation prevents race conditions
- **Symlink guards**: Broken or redirected symlinks are detected and skipped

## Install

```bash
# Via Homebrew tap
brew tap kin0kaze23/pulse
brew install pulse

# Via install script
curl -fsSL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash

# From source
git clone https://github.com/kin0kaze23/pulse.git
cd pulse
swift build -c release
cp .build/release/pulse /usr/local/bin/
```

## Tests

85 tests passing (70 PulseCore + 15 PulseCLI).

```bash
swift test
```
