# Phase 3A.1 Report — Packaging and Contract Hardening

**Date:** 2026-04-20
**Branch:** `phase0-hardening`
**Status:** Complete

---

## Deliverables

### A1: Homebrew Tap/Formula — Done

- `homebrew-pulse-cli/Formula/pulse.rb` — builds from source via SPM
- `homebrew-pulse-cli/README.md` — tap documentation
- Install: `brew tap kin0kaze23/pulse-cli && brew install pulse`
- Requires GitHub repo `kin0kaze23/homebrew-pulse-cli` to be created and pushed for remote tap support

### A2: Harden Install Script — Done

- `scripts/install.sh` — complete rewrite:
  - Architecture detection (Apple Silicon vs Intel via `uname -m`)
  - Smart install directory selection: Homebrew prefix → `/usr/local/bin` → `/opt/homebrew/bin` → `~/.local/bin`
  - Upgrade detection with confirmation prompt
  - Shell completion installation (zsh + bash)
  - Reinstall support with backup of existing binary
- `scripts/uninstall.sh` — new script:
  - Removes binary, completions, source directory (`~/.pulse-cli`)
  - Preserves user data

### A3: Harden JSON Output Schema — Done

- Added `schemaVersion: "1.0.0"` to all CLI JSON outputs
- Each command has its own error struct with stable error codes:
  - `AnalyzeCommand`: `AnalyzeJSON`, `JSONError`
  - `CleanCommand`: `CleanDryRunJSON`, `CleanJSONError`
  - `DoctorCommand`: `DoctorJSON`, `DoctorJSONError`
- Added `Codable` conformance to all PulseCore types:
  - `CleanupProfile`, `CleanupCategory`, `CleanupPriority`, `CleanupAction` (custom encode/decode for associated values)
  - `CleanupPlan`, `CleanupItem`, `CleanupWarning`, `CleanupResult` and nested types

### A4: Harden Pulse Doctor — Done

- 8 checks: Swift toolchain, Xcode, Homebrew, npm, yarn, pnpm, Full Disk Access, Disk space, Pulse location
- Meaningful exit codes:
  - `0` — All checks PASS (healthy)
  - `1` — Any check FAIL (needs attention)
  - `2` — No failures, but warnings present
- Per-check recommendations via `--json` output

### A5: Validate Raycast Extension — Done

- TypeScript compiles clean (`tsc --noEmit` passes)
- Fixed issues:
  - Installed `@raycast/utils` for `usePromise` hook
  - Replaced `extends "@raycast/config/tsconfig.json"` with standalone config + `skipLibCheck: true`
  - Fixed missing icon references (`Stethoscope` → `Hammer`, `CheckmarkCircle` → `CheckCircle`)
  - Replaced `Color.Gray` with `Color.SecondaryText`
  - Removed unsupported `navigationSubtitle` prop from doctor
  - Ran prettier fix
- Three commands: analyze, clean, doctor
- **Alfred support:** Deferred — not trivial, would require separate Swift/AppleScript extension. Raycast covers the primary use case.

---

## Files Changed

| File | Change |
|------|--------|
| `Sources/PulseCore/CleanupPlan.swift` | Added Codable to all public types |
| `Sources/PulseCLI/Commands/AnalyzeCommand.swift` | Added --json flag, schema structs |
| `Sources/PulseCLI/Commands/CleanCommand.swift` | Added --json to dry-run, schema structs |
| `Sources/PulseCLI/Commands/DoctorCommand.swift` | New command with exit codes |
| `Sources/PulseCLI/Commands/CompletionCommand.swift` | New command for shell completions |
| `Sources/PulseCLI/main.swift` | Added completion/doctor cases |
| `Sources/PulseCLI/OutputFormatter.swift` | Updated help text |
| `scripts/install.sh` | Complete rewrite |
| `scripts/uninstall.sh` | New file |
| `homebrew-pulse-cli/Formula/pulse.rb` | New file |
| `homebrew-pulse-cli/README.md` | New file |
| `extensions/pulse-raycast/package.json` | Added @raycast/utils, private flag |
| `extensions/pulse-raycast/tsconfig.json` | Standalone config, skipLibCheck |
| `extensions/pulse-raycast/src/commands/analyze.tsx` | Fixed usePromise import |
| `extensions/pulse-raycast/src/commands/clean.tsx` | Fixed usePromise import |
| `extensions/pulse-raycast/src/commands/doctor.tsx` | Fixed icons, removed navigationSubtitle |
| `extensions/pulse-raycast/src/utils.ts` | No functional change |

---

## JSON Schema Contract

All CLI JSON outputs follow this pattern:

```json
{
  "schemaVersion": "1.0.0",
  "command": "analyze|clean|doctor",
  "timestamp": "ISO-8601",
  // ... command-specific fields
}
```

Error responses:

```json
{
  "schemaVersion": "1.0.0",
  "command": "analyze|clean|doctor",
  "error": "Human-readable message",
  "code": "STABLE_ERROR_CODE"
}
```

Breaking changes to the schema require a `schemaVersion` bump.

---

## Test Results

- `swift build --target PulseCLI`: Pass
- `npx tsc --noEmit` (Raycast): Pass
- `npx ray lint` (Prettier/ESLint): Pass
- Unit tests: Pre-existing failure in `testPathSafetyAllowsLibraryPaths` (unrelated to Phase 3A.1 changes)

---

## Remaining Items

- **GitHub repo for Homebrew tap:** Create `kin0kaze23/homebrew-pulse-cli` and push `homebrew-pulse-cli/` contents
- **Raycast store publishing:** Requires Raycast account, author verification, and icon asset
- **Alfred support:** Deferred — low priority, not trivial to implement

---

## Next Steps

1. Create and push `kin0kaze23/homebrew-pulse-cli` GitHub repo
2. Rerun external alpha with hardened installer and JSON contracts
3. Evaluate Phase 3B (startup-risk auditor) after alpha feedback
