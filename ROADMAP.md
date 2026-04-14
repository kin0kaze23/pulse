# Pulse — Roadmap

> **Status:** active
> **Last updated:** 2026-03-29
> **Review trigger:** on strategic pivot or quarterly

## Vision

A native macOS menu bar system monitor — instant visibility into memory, CPU, and system health from the menu bar.

## Why This, Why Now

macOS users need lightweight system monitoring without opening Activity Monitor. Pulse lives in the menu bar with SwiftUI-native design, providing instant memory and CPU insights with one-click optimization.

## Current Phase

**Phase 0 — Repo Hardening** — Git hygiene, docs reconciliation, test credibility, concurrency safety

**Target:** 2026-04

## Milestones

| Milestone | Target | Status |
|---|---|---|
| Phase 0: Repo hardening | 2026-04 | In Progress |
| Phase 0.5: Concurrency safety | 2026-04 | Planned |
| Phase 1: PulseCore extraction | 2026-05 | Planned |
| Phase 2: PulseCLI v0.1 | 2026-05 | Planned |
| Phase 3: PulseApp shell | 2026-06 | Planned |
| Phase 4: External alpha | 2026-06 | Planned |

Status: ✅ Done | 🟡 In Progress | 🔴 Blocked | ⚪ Planned

## How We're Guiding This

- **Native macOS:** Swift + SwiftUI, macOS 14+
- **Menu bar first:** Minimal footprint, instant access
- **System-safe:** Sandboxed, respectful of macOS APIs
- **Design-polished:** Consistent with macOS design language

## Known Pivots

| Date | From | To | Rationale |
|---|---|---|---|
| — | — | — | No pivots recorded yet |

---

## Agent Integration

**This file is read by agents during startup.**

Placement: repo root (`Pulse/ROADMAP.md`), NOT in `docs/`.
Integration: Listed in `AGENTS.md` startup sequence (step 4b).

## Maintenance

- **Update trigger:** strategic pivot OR quarterly review
- **Update workflow:**
  - Automatic detection: `/checkpoint` flags when phase complete
  - Propose updates: `/update-roadmap --propose`
  - Apply with approval: Reply 'approved' or `/update-roadmap --apply`
  - Manual edit: `/update-roadmap --edit`
- **Time budget:** 30 seconds (approval) / 10 minutes (manual edit)
- **Owner:** Workspace owner (approval) + agents (drafting)
- **Archive:** Old versions stay in git history (no manual archiving needed)

**What agents can update (with approval):**
- ✅ Milestone status (🟡 → ✅, ⚪ → 🟡)
- ✅ "Current Phase" section
- ✅ "Last updated" date

**What stays human-only:**
- ❌ Vision statement
- ❌ "Why This, Why Now" rationale
- ❌ Strategic pillars
- ❌ New milestones (adding)
- ❌ Milestone reordering
- ❌ Pivots table
