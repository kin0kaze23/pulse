# Phase 3A.2 Report — Final Shipping Pass

**Date:** 2026-04-21
**Branch:** `phase0-hardening`
**Status:** GO — External alpha ready

---

## Changes Since 3A.1

### 1. Doctor `--json` Exit Code Fix

**Problem:** `pulse doctor --json` always returned exit code 0, even when checks failed. This broke automation trust.

**Fix:** Exit codes now computed from check results after JSON output:
- `0` — All checks PASS
- `1` — Any check FAIL
- `2` — No failures, but warnings present

Human and JSON modes now share the same exit code logic.

### 2. JSON Action Label Alignment

**Problem:** `analyze --json` used `"file"` for file deletions while `clean --dry-run --json` used `"delete"`. Commands used raw strings in clean but `"command:..."` prefix in analyze.

**Fix:** Single stable convention across all commands:
- `"delete"` — file deletion
- `"command:<cmd>"` — shell command to run (with `command:` prefix for easy script parsing)

Applied to:
- `AnalyzeCommand.actionLabel()` — changed `"file"` → `"delete"`
- `CleanCommand.actionLabel()` — added `"command:"` prefix back for commands
- Documentation comments updated to reflect the convention

### 3. Raycast JSON Type Alignment

**Problem:** TypeScript interfaces used `version: number` while Swift outputs `schemaVersion: "1.0.0"`.

**Fix:** Updated `utils.ts` interfaces:
- `AnalyzeJSON.version: number` → `schemaVersion: string`
- `CleanJSON.version: number` → `schemaVersion: string`

### 4. Homebrew Tap Published

**Created repos:**
- `kin0kaze23/pulse` — main Pulse repo (public)
- `kin0kaze23/homebrew-pulse-cli` — Homebrew tap (public)

**Tag:** `v0.1.0-alpha` points to latest commit on `phase0-hardening`.

**Note:** Homebrew sandbox conflicts with SwiftPM on macOS 26 SDK. The tap README now recommends the install script as the primary path, with `HOMEBREW_NO_SANDBOX=1 brew install pulse --build-from-source` as the fallback.

### 5. Install Script Fixes

**Problem:** Info/warn messages went to stdout and got mixed with return values in `$()` captures. `--target PulseCLI` compiled but didn't link the binary.

**Fix:**
- All `info`/`warn`/`error` calls in `setup_repo` and `build_cli` now redirect to stderr (`>&2`)
- Changed from `--target PulseCLI --target PulseCore` to `--product pulse` to produce the linked binary
- Binary path is now explicit: `.build/release/pulse`

---

## Verification Results

### Install Script

```
✅ Architecture detection (arm64)
✅ Cloned tag: v0.1.0-alpha
✅ Built in 7.54s
✅ Installed to /opt/homebrew/bin/pulse
✅ Version check: Pulse CLI 0.1.0-alpha
✅ Zsh completion installed to ~/.zsh/completions/_pulse
```

### CLI Commands

```
✅ pulse --version       → Pulse CLI 0.1.0-alpha
✅ pulse --help          → All 6 commands listed
✅ pulse doctor          → 9 checks, exit code 0
✅ pulse doctor --json   → Valid JSON with schemaVersion, exit code 0
✅ pulse analyze --json  → Valid JSON, action="delete", schemaVersion="1.0.0"
✅ pulse clean --dry-run --json → Valid JSON, action="delete", mode="dry-run", schemaVersion="1.0.0"
✅ pulse completion zsh  → Generates completion script
```

### JSON Contract

Both `analyze --json` and `clean --dry-run --json` now use:
- `schemaVersion: "1.0.0"` (string, not number)
- `action: "delete"` for file deletions (not "file")
- `action: "command:<cmd>"` for shell commands (consistent prefix)

Error responses use:
- `schemaVersion: "1.0.0"`
- `code: "ENCODE_FAILED"` (stable error code)

### TypeScript

```
✅ npx tsc --noEmit    → 0 errors
✅ npx ray lint        → Pass (except store metadata: author/icon)
```

### Swift Build

```
✅ swift build --target PulseCLI  → Clean
✅ swift build --product pulse    → Links binary
```

---

## Files Changed (3A.2 Only)

| File | Change |
|------|--------|
| `Sources/PulseCLI/Commands/DoctorCommand.swift` | Exit codes computed after JSON output |
| `Sources/PulseCLI/Commands/AnalyzeCommand.swift` | actionLabel: "file" → "delete" |
| `Sources/PulseCLI/Commands/CleanCommand.swift` | actionLabel: added "command:" prefix |
| `extensions/pulse-raycast/src/utils.ts` | version: number → schemaVersion: string |
| `scripts/install.sh` | stderr redirections, --product pulse |
| `homebrew-pulse-cli/Formula/pulse.rb` | --product pulse, explicit version |
| `homebrew-pulse-cli/README.md` | Install script as recommended path |

---

## External Alpha Decision

**LAUNCH NOW.**

All Phase 3A.1 and 3A.2 blockers resolved:
- ✅ Homebrew tap published (`kin0kaze23/homebrew-pulse-cli`)
- ✅ Doctor --json exit codes match human mode (0/1/2)
- ✅ JSON action labels aligned ("delete" / "command:...")
- ✅ Install script works end-to-end from GitHub
- ✅ TypeScript compiles clean
- ✅ Swift builds and links correctly

Remaining known issues (non-blocking for alpha):
- Homebrew `--build-from-source` requires `HOMEBREW_NO_SANDBOX=1` on macOS 26 SDK
- Raycast extension needs store author setup for public publishing
- No pre-built bottles (users build from source via install script)

---

## Recommended Next Steps (After Alpha Feedback)

1. Collect alpha feedback on install experience and JSON output
2. Phase 3B: `pulse audit startup` (highest-value audit, most visible)
3. Then: `pulse audit disk-pressure`
4. Then: `pulse audit persistence`
5. Then: `pulse audit hot`
