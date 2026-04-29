# Pulse — Agent Rules

> For AI agents working on this repo.

## Strategic Context (read first)

This repo is one of three products in the AI Workstation Suite (Pulse · trace-eval · agent-ready). Before any non-trivial work, read the suite-level strategy at:

`/Users/jonathannugroho/Developer/PersonalProjects/AI_WORKSTATION_SUITE.md`

Your product's specific role: **§5.1 — Pulse: host health for AI workstations.** Keep the Mac fast for Claude Code and Cursor. Read-only commands (`analyze` · `audit` · `doctor` · `status`) are exposed via MCP; destructive commands (`clean`, `--apply`) stay terminal-only by deliberate design (see §1 of the strategy doc).

When the strategy and this file conflict, the strategy doc wins for vision and direction; this file wins for repo-local execution rules.

## Startup Reading Order

1. `README.md` — product overview and current commands.
2. `ROADMAP.md` — phase plan and milestones.
3. `ARCHITECTURE.md` — PulseCore / PulseCLI / PulseApp layering.
4. `SECURITY.md` — safety model (typed actions, TOCTOU protection, protected paths).
5. `NOW.md` if present — current focused work.

## Repo Map

```
Package.swift            SwiftPM manifest
Sources/
  PulseCore/             pure Swift engine — no SwiftUI, no AppKit, no singletons
  PulseCLI/              thin CLI over PulseCore (binary: `pulse`)
PulseApp/                SwiftUI menu bar app (depends on PulseCore) — secondary surface
Tests/                   XCTest suites
docs/
  TROUBLESHOOTING.md
  XCODE_PROJECT_SETUP.md
scripts/                 release + install scripts
```

## Before You Edit

1. Run `swift build` — must succeed before any change.
2. Run `swift test` — must stay green; add tests for new behavior.
3. Sensitive paths (any deletion logic, profile definitions, safety validators) → HIGH-RISK lane in the workspace policy. Surface to user before committing.

## Repo Hygiene

- Only `README.md`, `ROADMAP.md`, `ARCHITECTURE.md`, `SECURITY.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE` at root.
- Never commit `.build/`, `.swiftpm/`, derived data, or `.DS_Store`.
- Never commit signed artifacts or notarization tickets.

## Safety Posture

Pulse can permanently delete files. Every change to deletion logic must preserve:

- **Preview-first:** dry-run is the default for any destructive operation.
- **Typed actions:** no string-based dispatch — every cleanup action is a typed enum.
- **TOCTOU protection:** paths re-validated immediately before deletion.
- **Trash-first:** files go to Trash unless the user explicitly opts into permanent deletion.
- **Protected paths:** `/System`, `/usr`, `/bin`, `/sbin`, `~/Documents`, `~/Desktop`, `~/Downloads`, `.app` bundles are blocked at the code level — never bypass.
- **Symlink guards:** broken or redirected symlinks are detected and skipped.

Adding a new cleanup profile: write the safety review in the PR description before writing code.

## MCP Boundary (per strategy §1, §5.1)

Read-only commands are MCP-eligible: `analyze`, `audit`, `audit index-bloat`, `audit agent-data`, `audit models`, `doctor`, `status`.

Destructive commands stay CLI-only: `clean`, `cleanup`, anything with `--apply`. Do **not** expose these via MCP — the trust model relies on the user invoking them in their own terminal with the existing dashboard preview.

## Development

```bash
swift build              # build everything
swift test               # run all tests
swift run pulse          # run CLI locally
swift run pulse doctor   # quick smoke check
```
