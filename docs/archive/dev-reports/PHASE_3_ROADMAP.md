# Phase 3 Roadmap

**Date:** 2026-04-19
**Starting point:** v0.1.0-alpha (74 tests passing, xcode/homebrew/node profiles)
**Strategy:** Beat Mole by being safer, more developer-specific, and more explainable — not broader.

---

## Competitive Positioning

| Dimension | Mole | Pulse (current) | Pulse (target) |
|-----------|------|----------------|----------------|
| **Install** | `brew install mole`, install script | `git clone && swift build` | `brew install`, install script, completion |
| **Scope** | Broad: clean, optimize, analyze, status, purge, uninstall | Narrow: xcode/homebrew/node cleanup | Narrow + audit: developer-machine speed & security |
| **Trust** | Dry-run, whitelist, protected paths | Preview-first, Trash-first, typed actions | + rebuild cost, risk labels, undo guidance, operations log |
| **Developer focus** | Broad artifact purge (node_modules, target, .build, venv) | Cache-only cleanup, no project files | Age-aware project artifacts, recent-project protection |
| **Security** | Not a security tool | Security scanner in app (not CLI) | `pulse audit persistence`, `permissions`, `browser-ext`, `network` |
| **Output** | `--json` for analyze, status | Human-readable only | `--json` for all commands, structured errors |
| **Automation** | Raycast/Alfred, completion | None | Completion, Raycast/Alfred, JSON scripting |

**Winning wedge:** "The safest developer cleanup and startup-risk audit tool for macOS."

---

## Phase 3A — CLI Friction Parity

**Goal:** Make Pulse as easy to trigger and automate as Mole.

| # | Feature | Effort | Rationale |
|---|---------|--------|-----------|
| A1 | `pulse analyze --json` | Low | Scripting, CI, AI automation |
| A2 | `pulse clean --dry-run --json` | Low | Scripting, CI, AI automation |
| A3 | Shell completion (bash/zsh) | Medium | Tab-completion for commands, profiles, flags |
| A4 | `pulse completion` command | Low | Generate completion scripts for user to source |
| A5 | Install script | Medium | One-liner install without git clone |
| A6 | Homebrew install path | High | Tap or formula — requires hosting binaries |
| A7 | `pulse doctor` | Medium | Verify install, permissions, toolchain status |
| A8 | Raycast/Alfred quick launchers | Medium | Discoverability and ease of use |

**Definition of Done:**
- [ ] `pulse analyze --json` outputs valid JSON with stable schema
- [ ] `pulse clean --dry-run --json` outputs valid JSON with stable schema
- [ ] `pulse completion zsh` prints a completion script that can be sourced
- [ ] Install script works: `curl -sL ... | bash` builds and links `pulse`
- [ ] `pulse doctor` verifies: swift toolchain, Xcode installed, Homebrew installed, npm/yarn/pnpm status, permissions
- [ ] Raycast extension: at least 2 commands (analyze, clean --dry-run)
- [ ] All new commands have tests
- [ ] README updated with install instructions

**Out of scope for 3A:**
- Homebrew formula (requires notarized binary, codesigning — deferred until app packaging is solved)
- `pulse update` (requires version management infrastructure)

---

## Phase 3B — Developer Speed Audits

**Goal:** Real "faster Mac" features that are developer-relevant, not generic health scores.

| # | Command | Effort | What it does |
|---|---------|--------|-------------|
| B1 | `pulse audit startup` | Medium | LaunchAgents, LaunchDaemons, login items, background helpers, startup cost estimate |
| B2 | `pulse audit hot` | Medium | Top memory/CPU/I/O hogs, sustained offenders, developer process explanations |
| B3 | `pulse audit disk-pressure` | Low | Free space vs. swap threshold, warns when low space hurts performance, suggests best cleanup action |

**All must be:**
- Read-only (no mutations)
- Explain findings clearly ("why this matters")
- Recommend safe actions ("what to do next")
- Conservative in conclusions ("here's what I know vs don't know")

**Definition of Done:**
- [ ] Each command produces human-readable output with: finding, severity, explanation, recommendation
- [ ] Each command has `--json` output
- [ ] Each command has tests (mock system data)
- [ ] README documents what each audit checks and its limitations

---

## Phase 3C — Developer Security Audits

**Goal:** Own "developer-machine persistence and permissions audit" — not antivirus.

| # | Command | Effort | What it does |
|---|---------|--------|-------------|
| C1 | `pulse audit persistence` | Medium | LaunchAgents, LaunchDaemons, Login Items, suspicious helpers, changes since last run |
| C2 | `pulse audit permissions` | Low | FDA, Accessibility, Automation, Input Monitoring, Screen Recording status |
| C3 | `pulse audit browser-ext` | Low | Safari, Chrome, Firefox extensions — developer-relevant risks |
| C4 | `pulse audit network` | Medium | Local proxies, custom DNS/VPN/interceptors, unknown local listeners |

**All must be:**
- Read-only, high-trust, conservative
- Explicitly state what Pulse knows vs doesn't know
- No false positives preferred over catching everything

**Definition of Done:**
- [ ] Each command outputs findings with: item, risk level, explanation, confidence ("verified", "suspicious", "unknown")
- [ ] Each command has `--json` output
- [ ] Each command has tests
- [ ] README documents limitations of each audit

---

## Phase 3D — Careful Dev Artifact Cleanup

**Goal:** Expand cleanup profiles without becoming a generic cleaner.

| # | Profile | Effort | What it cleans |
|---|---------|--------|---------------|
| D1 | `cargo` | Low | `~/.cargo/registry`, `~/.cargo/git`, `target/` in known dirs |
| D2 | `pip` | Low | `~/.cache/pip`, `__pycache__`, `.venv` (age-aware) |
| D3 | `go` | Low | `~/go/pkg/mod`, `~/go/pkg/sumdb`, `~/go/src` |
| D4 | `gradle` | Low | `~/.gradle/caches`, `~/.gradle/wrapper` |
| D5 | Project artifacts | High | Age-aware, scan-dirs-only, recent-project protection |

**Rules:**
- NO `node_modules` by default
- Project artifact cleanup requires: age awareness, recent-project protection, explicit scan directories, dry-run default
- All new profiles must have: typed actions, explicit risk labels, tests

**Definition of Done:**
- [ ] Each profile scans correctly and reports accurate sizes
- [ ] Each profile has `--dry-run` and `--apply` support
- [ ] Each profile has tests
- [ ] Project artifact cleanup has age threshold, recent-project protection, explicit scan dirs

---

## What NOT to Do

- Do not clone Mole feature-for-feature
- Do not add destructive project cleanup too early
- Do not market broad "security" before real audit depth
- Do not market broad "performance optimization" before proving it
- Do not become a generic Mac cleaner first
- Do not add `--yes`/`--force` flag during alpha (changes contract mid-flight)
- Do not add Homebrew formula until app packaging + notarization is solved

---

## Execution Order

1. **Phase 3A** (current) — reduce friction, make CLI usable without git clone
2. **Phase 3B** — give developers real "why is my Mac slow" answers
3. **Phase 3C** — give developers real "is my machine compromised" answers
4. **Phase 3D** — expand cleanup profiles carefully

Each phase must ship with: tests, sample output, documentation, and a short benchmark or real-world example.
