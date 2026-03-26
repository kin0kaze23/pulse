# Pulse - Agent Instructions

## Repo Memory

| Field | Value |
|---|---|
| Tech Stack | Swift + SwiftUI |
| Gate Commands | `swift build` · `swift test` |

## Run Commands
- Install: `swift package resolve`
- Dev: `swift run Pulse`
- Build: `swift build`

## Quality Gates
- Lint: No dedicated lint command is defined in `Package.swift`
- Typecheck: `swift build`
- Test: `swift test`
- Build: `swift build`

## Architecture Hotspots
- `MemoryMonitor/Sources/App.swift` - app entry, menu bar lifecycle, and window management start here
- `MemoryMonitor/Sources/Services/` - system monitors, optimizers, and scanners interact with sensitive macOS APIs
- `MemoryMonitor/Sources/Utilities/DesignSystem.swift` and `Views/` - visual consistency and main dashboard behavior live here

## Coding Conventions
- Keep system-facing logic inside `Services/` and keep view composition in SwiftUI views
- Preserve the macOS 14+ SwiftUI app structure defined by the executable target and test target layout

## Dangerous Areas
- `Services/` monitors and scanners - mistakes can produce bad telemetry or unsafe cleanup behavior
- `Pulse.app/` and packaging outputs - app bundle changes can drift from the source build
- `Views/` and `DesignSystem.swift` - regressions here quickly affect the menu bar and dashboard UX

## Definition of Done
- Quality gates pass (lint -> typecheck -> test -> build)
- No new TypeScript errors
- PR created with description
- The app still builds, tests pass, and menu bar monitoring behavior remains intact
