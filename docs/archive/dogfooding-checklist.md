# Dogfooding Checklist — Daily Use

> Use this to validate Phase 2 + Sprint 1 during personal use.

## Daily Workflow Items

### Dashboard

- [ ] **Launch** — App starts without crash
- [ ] **Health score** — Shows accurate score (0-100)
- [ ] **Memory display** — Correct GB used/total
- [ ] **Tab navigation** — All tabs (Health, Memory, System, Caches, Developer, Security) accessible
- [ ] **Quick Clean button** — Triggers cleanup, shows progress
- [ ] **Results display** — Shows freed amount after cleanup

### MenuBarLite

- [ ] **Icon appears** — Menu bar icon visible
- [ ] **Popover opens** — Click shows Vitality Orb + stats
- [ ] **Optimize button** — Contextual label shows (Free X GB or Quick Clean)
- [ ] **Real-time status** — Progress messages display during work
- [ ] **Result banner** — Shows freed amount with bounce animation

### Progress Clarity

- [ ] **During scan** — Status message shows current action
- [ ] **During cleanup** — Step-by-step progress visible
- [ ] **Completion** — Clear result banner with amount freed

### Trust / Safety

- [ ] **Confirmation dialog** — Appears for significant cleanups
- [ ] **Category breakdown** — Shows what's being cleaned (Dev/Browser/System)
- [ ] **No accidental deletes** — Trash-first approach working
- [ ] **Process protection** — Critical processes not killed

### State Consistency

- [ ] **Dashboard ↔ Menu bar** — Same memory/CPU readings
- [ ] **Health score** — Consistent between views
- [ ] **Optimization status** — Both views show same state (working/idle)

### Result Usefulness

- [ ] **Amount freed** — Accurate MB/GB shown
- [ ] **Categories** — Icons show what was cleaned
- [ ] **Duration** — Quick (< 10 seconds) for simple cleanups
- [ ] **Recent result** — Button shows last freed amount briefly

---

## Quick Validation (2 min)

1. Open app → Dashboard loads
2. Click menu bar → Popover shows orb
3. Click "Quick Clean" → Progress appears
4. Wait for completion → Result banner shows
5. Check freed amount → Reasonable (50 MB - 2 GB typical)

**If all pass: Dogfooding ready.**

---

## Issue Reporting

If any item fails:
1. Note exact behavior
2. Screenshot if UI issue
3. Check Console.app for errors
4. Report in project issue tracker

---