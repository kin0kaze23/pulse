# Pulse CLI v0.1.0-alpha

**Release date:** 2026-04-17
**Branch:** phase0-hardening
**Build:** `swift build`

---

## What's New

Pulse CLI is a command-line interface for scanning and cleaning system caches on macOS. This is the **first alpha release** — only three profiles are supported, and all operations are **dry-run by default**.

### Commands

| Command | Description |
|---------|-------------|
| `pulse analyze` | Scan all profiles, show reclaimable space |
| `pulse clean --dry-run` | Preview cleanup for all profiles |
| `pulse clean --profile <name> --dry-run` | Preview cleanup for specific profile |
| `pulse clean --profile <name> --apply` | Execute cleanup (requires "yes" confirmation) |
| `pulse --help` | Show help |
| `pulse --version` | Show version |

### Supported Profiles

| Profile | What it cleans |
|---------|---------------|
| `xcode` | DerivedData, Archives, DeviceSupport, Simulators |
| `homebrew` | Downloads cache, old formulae/casks |
| `node` | npm cache, Yarn cache, pnpm store |

### Safety

- **Preview-first**: Dry-run is the default
- **Confirmation required**: `--apply` requires typing "yes"
- **Protected paths**: System paths, user data, and app bundles cannot be deleted
- **Trash-first**: Files go to Trash before permanent deletion (configurable)

### What's NOT Included

- Docker, browser, system cleanup
- Bun, pip, Go, Cargo caches
- Scheduling or automation
- Telemetry or analytics
- Profile configuration files
- Concurrent cleanup

---

## How to Install

```bash
git clone https://github.com/jonathannugroho/pulse.git
cd pulse
git checkout phase0-hardening
swift build
.build/debug/pulse --help
```

## Known Issues

1. `--version` shows hardcoded "0.1.0-alpha" (not from git tag)
2. `--apply` cannot be scripted (no `--yes` flag)
3. Homebrew may show "Nothing to clean" if caches are below 50 MB threshold
4. No JSON or machine-readable output

## Providing Feedback

If you're testing this alpha, please open an issue with the **Alpha Feedback** template:
https://github.com/jonathannugroho/pulse/issues/new/choose

We want to know:
- Whether install worked
- Whether output was clear
- How much space it found
- Whether you trusted it
- What confused you

---

## Tests

74 tests passing (61 PulseCore + 13 PulseCLI).

```bash
swift test
```
