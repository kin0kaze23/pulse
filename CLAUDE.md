---
# Pulse — Claude Code Context
updated: 2026-03-29
---

## Identity

Native macOS 14+ menu bar app. System monitor: memory, CPU, disk, process health, security scanner.
Stack: Swift 5.9 + SwiftUI + Package.swift. No external dependencies. Deploy: local app only.

## Architecture

```
MemoryMonitor/Sources/    → all production Swift (entry: App.swift)
  App.swift               → menu bar lifecycle, window management
  Models/                 → data types (AppSettings, health scores, etc.)
  Services/               → MemoryMonitorManager (central coordinator)
    Monitors/             → SystemMemoryMonitor, ProcessMemoryMonitor, CPUMonitor, DiskMonitor
    Health/               → SystemHealthMonitor
    Security/             → SecurityScanner
Tests/                    → XCTest unit tests (one file per service)
Package.swift             → swift-tools-version 5.9, target: Pulse, testTarget: PulseTests
```

Central pattern: `MemoryMonitorManager` is the coordinator — it connects all monitor services and publishes state. Views observe it via `@ObservedObject` / `@StateObject`.

## Key constraints

- **macOS 14+ only** — do not add availability guards for older OS versions
- **No SwiftUI previews for menu bar windows** — previews crash; use the simulator or live app
- **XCTest only** — no Swift Testing framework; all test files import XCTest
- **No Swift Concurrency (async/await) in monitors** — monitors use Timer/NotificationCenter patterns; do not refactor to async without explicit approval

## Test and build commands

```bash
swift build                          # build
swift test                           # run all tests
swift test --filter PulseTests       # targeted test run
swift package resolve                # resolve dependencies
```
