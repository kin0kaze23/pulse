# Phase 3: Enhanced Features

**Date:** 2026-03-31
**Lane:** STANDARD
**Risk Score:** 5/10
**Verification Profile:** ui-surface

---

## Objective

Implement 4 enhanced features to add polish and advanced functionality:

1. **Trigger History UI** — Visual timeline of automation events
2. **Large File Finder** — Identify space consumers with safe deletion
3. **Privacy Permissions Audit** — Review app permissions
4. **Menu Bar Quick Actions** — One-click cleanup from menu bar

---

## Touch List

| File | Action | Risk |
|------|--------|------|
| `Models/TriggerEvent.swift` | CREATE | LOW |
| `Models/LargeFileScanResult.swift` | CREATE | LOW |
| `Models/AppPermission.swift` | CREATE | LOW |
| `Services/HistoricalMetricsService.swift` | CREATE | MEDIUM |
| `Services/LargeFileFinder.swift` | CREATE | MEDIUM |
| `Services/PermissionsAuditService.swift` | CREATE | MEDIUM |
| `Services/SmartTriggerMonitor.swift` | MODIFY | LOW |
| `Services/ComprehensiveOptimizer.swift` | MODIFY | LOW |
| `Views/TriggerHistoryView.swift` | CREATE | LOW |
| `Views/LargeFileFinderView.swift` | CREATE | LOW |
| `Views/PrivacyAuditView.swift` | CREATE | LOW |
| `Views/MenuBarLiteView.swift` | MODIFY | MEDIUM |
| `Views/SettingsView.swift` | MODIFY (add tabs) | LOW |
| `Views/SecurityView.swift` | MODIFY (add section) | LOW |
| `Tests/HistoricalMetricsServiceTests.swift` | CREATE | LOW |
| `Tests/LargeFileFinderTests.swift` | CREATE | LOW |
| `Tests/PermissionsAuditServiceTests.swift` | CREATE | LOW |

---

## Success Criteria

### Feature 1: Trigger History UI
- [x] TriggerEvent model created with Codable support
- [x] HistoricalMetricsService logs events to disk
- [x] SmartTriggerMonitor fires events to history
- [x] TriggerHistoryView shows timeline with filters
- [x] Summary cards show today/week stats
- [x] Events persist across app restarts

### Feature 2: Large File Finder
- [x] LargeFileFinder scans locations efficiently
- [x] File type detection works accurately
- [x] LargeFileFinderView shows sortable list
- [x] Safe deletion with trash-first approach
- [x] Protected paths whitelist enforced
- [x] Progress indicator during scan

### Feature 3: Privacy Permissions Audit
- [x] PermissionsAuditService reads TCC database
- [x] Graceful fallback when FDA not granted
- [x] PrivacyAuditView shows permission sections
- [x] One-click link to System Settings
- [x] Works across macOS versions

### Feature 4: Menu Bar Quick Actions
- [x] MenuBarLiteView has quick cleanup button
- [x] Stop Memory Hog with confirmation
- [x] Auto-hide after action completes
- [x] Visual feedback during operations

### Quality Gates
- [x] All new code passes lint
- [x] App builds successfully
- [x] 30+ new tests added (total: 150+)
- [ ] All tests pass (95%+ pass rate)
- [ ] No regressions in Phase 1/2 features

---

## Implementation Order

**Phase 3.1: Trigger History UI** (Files: 5)
1. Create TriggerEvent model
2. Create HistoricalMetricsService
3. Integrate with SmartTriggerMonitor
4. Build TriggerHistoryView
5. Add persistence layer

**Phase 3.2: Large File Finder** (Files: 4)
1. Create LargeFileScanResult model
2. Create LargeFileFinder service
3. Build LargeFileFinderView
4. Add safety checks and whitelist

**Phase 3.3: Privacy Permissions Audit** (Files: 4)
1. Create AppPermission model
2. Create PermissionsAuditService
3. Build PrivacyAuditView
4. Add FDA request flow

**Phase 3.4: Menu Bar Quick Actions** (Files: 2)
1. Add quickCleanup to ComprehensiveOptimizer
2. Update MenuBarLiteView

**Phase 3.5: Testing & Polish**
1. Write unit tests for all services
2. Manual QA for all features
3. Documentation

---

## Autonomy Budget

| Budget | Limit | Notes |
|--------|-------|-------|
| Max files | 17 | Touch list = 17 files |
| Max commands | 20 | tmutil, defaults, swift, etc. |
| Max retries | 2 | Per gate |
| Expansions | 0 | User approval required |

---

## Risk Factors

| Factor | Score | Notes |
|--------|-------|-------|
| Domain sensitivity | 2 | File deletion, permissions access |
| Blast radius | 1 | New features, isolated code |
| State impact | 2 | Destructive ops require confirmation |
| External dependency | 0 | Standard macOS APIs only |
| Rollback difficulty | 1 | Simple git checkout |
| Ambiguity | 0 | Detailed implementation plan |
| **Total** | **6/10** | Borderline HIGH-RISK |

**Lane Adjustment:** Keeping STANDARD due to:
- All destructive ops have confirmations
- Trash-first approach for file deletion
- Graceful fallbacks for permissions

---

## Dependencies

- macOS 14+ APIs (FileManager, Process, UserNotifications)
- TCC database access (requires Full Disk Access)
- SmartTriggerMonitor (Phase 2) for trigger history
- ComprehensiveOptimizer (Phase 1) for quick cleanup

---

## Out of Scope

- Real-time threat monitoring
- Menu bar widgets (Sonoma+ only)
- iCloud sync
- Weekly reports
- Browser extensions

---

## Rollback Plan

**Type:** discard-working-tree

**Scope:** All changes in touch list

**Action:**
```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse
git checkout -- .
```

**Verify:**
```bash
swift build  # Should succeed
swift test   # Should pass (118 tests from Phase 2)
```

---

## Verification Profile: ui-surface

**Gates in order:**
1. `swiftlint` — lint
2. `swift build` — build
3. `swift test` — tests
4. Manual QA — UI verification

---

*Phase 3 Planning Complete*
*Ready for /implement*
