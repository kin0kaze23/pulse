# Pulse

> Safe cleanup and machine audit for macOS developers

[![CI](https://github.com/kin0kaze23/pulse/actions/workflows/ci.yml/badge.svg)](https://github.com/kin0kaze23/pulse/actions/workflows/ci.yml)
[![Release](https://github.com/kin0kaze23/pulse/actions/workflows/release-cli.yml/badge.svg)](https://github.com/kin0kaze23/pulse/actions/workflows/release-cli.yml)
![macOS](https://img.shields.io/badge/macOS-14.0+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue)

Pulse helps macOS developers **safely reclaim disk space** from developer junk and system bloat, and **audit their machine** for stale tooling, orphaned configs, and broken symlinks.

Unlike broad "Mac cleaner" tools, Pulse is **narrow, transparent, and automation-first**. Every operation is preview-first, uses typed actions, and produces stable JSON for scripting.

> **Alpha / pre-release**
> Pulse is currently in controlled external alpha. Review `--dry-run` output before applying cleanup, and make sure you have a current backup the first time you use destructive commands.

---

## Quick Start

### Install

```bash
brew tap kin0kaze23/pulse
brew install pulse
```

Or install via script:

```bash
curl -fsSL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash
```

### First Run

```bash
pulse           # Open the interactive command dashboard
pulse analyze   # Scan for reclaimable space
pulse scan      # Friendly alias for analyze
pulse artifacts # Find build artifacts in your projects
pulse audit     # Check dev environment health
pulse audit index-bloat  # Find repos slowing AI IDE indexing
pulse audit agent-data   # Review Claude/Cursor data retention
pulse audit models       # Review Ollama / LM Studio model storage
pulse doctor    # Verify your setup
```

### Recommended First-Time Flow

```bash
pulse doctor
pulse analyze
pulse clean
```

In a normal terminal, `pulse clean` shows a guided preview and lets you:

- press **Enter** to clean recommended items
- press **p** to choose a profile
- press **a** to clean everything shown
- press **q** to cancel

Then, if the preview looks right:

```bash
pulse clean --profile xcode --apply
```

---

## Commands

| Command | Description | JSON |
|---------|-------------|------|
| `pulse analyze` | Scan tool caches (Xcode, Homebrew, Node, Python) | ✅ |
| `pulse scan` | Friendly alias for `pulse analyze` | ✅ |
| `pulse artifacts` | Scan project build artifacts (node_modules, .build, target, venv, etc.) | ✅ |
| `pulse audit` | Scan dev environment (stale simulators, orphaned taps, dead symlinks, old toolchains) | ✅ |
| `pulse audit index-bloat` | Audit repos that slow Cursor / VS Code indexing | ✅ |
| `pulse audit agent-data` | Audit Claude/Cursor data retention and cache sprawl | ✅ |
| `pulse audit models` | Audit Ollama / LM Studio model storage and duplication risk | ✅ |
| `pulse clean` | Safe default preview for all cleanup profiles | ✅ |
| `pulse cleanup` | Friendly alias for `pulse clean` | ✅ |
| `pulse clean --dry-run` | Preview what would be cleaned | ✅ |
| `pulse clean --profile <name> --apply` | Execute cleanup | ✅ |
| `pulse clean --profile <name> --apply --yes` | Execute cleanup (CI/CD, no prompt) | ✅ |
| `pulse doctor` | Verify installation and environment | ✅ |
| `pulse completion <shell>` | Generate shell completion scripts | — |

### Auto JSON Detection

When output is piped (not a TTY), Pulse automatically switches to JSON:

```bash
pulse doctor | jq '.hasFailures'    # false
pulse analyze | jq '.totalSizeMB'   # 2150.5
pulse audit | jq '.criticalCount'   # 0
```

### Cleanup Profiles

| Profile | What it cleans | Method |
|---------|---------------|--------|
| `xcode` | DerivedData, Archives, DeviceSupport, Simulators | File deletion |
| `homebrew` | Download cache, old formulae/casks | `brew cleanup` |
| `node` | npm cache, Yarn cache, pnpm store | File deletion |
| `python` | pip, Poetry, and uv caches | File deletion |
| `bun` | Bun install cache | File deletion |
| `rust` | Cargo registry and git caches | File deletion |
| `claude` | Claude Code logs, caches, transcripts, session artifacts | File deletion |
| `cursor` | Cursor caches, logs, extension caches, workspace storage | File deletion |

### Artifact Types (16 supported)

| Artifact | Tool | Typical Size |
|----------|------|-------------|
| `node_modules` | npm/yarn/pnpm | 100MB – 5GB |
| `.build` | SwiftPM | 50MB – 2GB |
| `target` | Cargo/Rust | 100MB – 3GB |
| `dist` | Vite/Webpack/Rollup | 10MB – 500MB |
| `venv` / `.venv` | Python venv | 50MB – 2GB |
| `__pycache__` | Python | 5MB – 200MB |
| `.dart_tool` | Dart/Flutter | 20MB – 500MB |
| `Pods` | CocoaPods | 100MB – 3GB |
| `.next` | Next.js | 10MB – 500MB |
| `.nuxt` | Nuxt.js | 10MB – 500MB |
| `.parcel-cache` | Parcel | 5MB – 200MB |
| `elm-stuff` | Elm | 5MB – 100MB |
| `go-cache` | Go modules | 50MB – 500MB |
| `bun-cache` | Bun | 20MB – 200MB |

### What Pulse Will NOT Touch

- **Project-local files**: `node_modules` in your active projects is never touched by `pulse clean`
- **System-critical paths**: `/System`, `/usr`, `/bin`, `/sbin` are protected
- **User data**: `~/Documents`, `~/Desktop`, `~/Downloads` are protected
- **App bundles**: `.app` files are never deleted
- **Docker, browser caches, system logs**: Deliberately excluded — not our scope

---

## Safety Model

Pulse is designed for **trust over breadth**:

1. **Preview-first**: Dry-run is the default. See exactly what will be deleted before it happens.
2. **Confirmation required**: `--apply` requires typing "yes" (or use `--yes` for CI).
3. **Trash-first by default**: Files go to Trash, not permanent deletion.
4. **Protected paths**: System paths, user data, and app bundles are blocked at the code level.
5. **Typed actions**: No string-based routing — every cleanup action is a typed enum.
6. **TOCTOU protection**: Paths are re-validated immediately before deletion to prevent race conditions.
7. **Symlink guards**: Broken or redirected symlinks are detected and skipped.
8. **Stable JSON schemas**: Every command documents its schema version for reliable scripting.

---

## Configuration

Pulse uses `~/.config/pulse/config.json` with safe defaults:

```json
{
  "artifactScanPaths": ["~/Developer", "~/GitHub", "~/Projects"],
  "artifactMinAgeDays": 7,
  "artifactMinSizeMB": 100,
  "excludedPaths": []
}
```

All fields are optional — defaults are used if the file doesn't exist.

---

## Architecture

```
PulseCore        → Pure Swift engine (no SwiftUI, no AppKit, no singletons)
PulseCLI         → Thin CLI over PulseCore (executable)
PulseApp         → SwiftUI menu bar app (depends on PulseCore)
```

Every command outputs stable JSON with `schemaVersion` for reliable automation:

```json
{
  "schemaVersion": "1.0.0",
  "command": "analyze",
  "timestamp": "2026-04-23T09:00:00Z",
  "totalSizeMB": 2150.5,
  "itemCount": 4,
  "items": [...]
}
```

---

## PulseApp (macOS Menu Bar)

Pulse also includes a native SwiftUI menu bar app with real-time monitoring, health scoring, and process management. See [PulseApp](PulseApp/) for details.

---

## Development

```bash
swift build          # Build everything
swift test           # Run all tests
swift run pulse      # Run CLI
```

---

## License

MIT. See [LICENSE](LICENSE) for details.
