---
name: SmartTriggerMonitorTests Tech Debt
description: AlertManager lazy initialization for test infrastructure
type: project
---

# Tech Debt: AlertManager Testability

**Created:** 2026-04-01

## Issue
SmartTriggerMonitorTests crashes in xctest due to UNUserNotificationCenter accessing mainBundle (nil in test environment). This is a pre-existing issue from Phase 2.

## Root Cause
AlertManager accesses `UNUserNotificationCenter.current()` at module load time via singleton, which crashes when Bundle.main.bundleIdentifier is nil (xctest environment).

## Required Changes
1. Convert AlertManager singleton to lazy initialization
2. Add environment detection to defer notification center access
3. Update tests to work with injectable dependencies

## Files to Modify
- `MemoryMonitor/Sources/Services/AlertManager.swift` — Major refactor
- `MemoryMonitor/Sources/Services/SmartTriggerMonitor.swift` — Indirect
- `Tests/SmartTriggerMonitorTests.swift` — Update for new architecture

## Risk Level
MEDIUM — Singleton lifecycle changes carry regression risk

## Complexity
3-5 hours

## Defer Until
After Interaction Polish Sprint 1 (this sprint)

## Justification
- Zero user impact (only affects test infrastructure)
- App works correctly in production
- Current test suite passes at 100% with XFail acknowledgment