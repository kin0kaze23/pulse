# Phase 3.5: Testing & Polish

**Date:** 2026-04-01
**Lane:** FAST
**Risk Score:** 2/10
**Verification Profile:** logic-backend

---

## Objective

Finalize Phase 3 with testing and polish:
1. Add unit tests for new Phase 3 services
2. Manual QA verification
3. Documentation updates

---

## Touch List

| File | Action | Risk |
|------|--------|------|
| `Tests/HistoricalMetricsServiceTests.swift` | CREATE | LOW |
| `Tests/LargeFileFinderTests.swift` | CREATE | LOW |
| `Tests/PermissionsAuditServiceTests.swift` | CREATE | LOW |
| `Tests/TriggerEventTests.swift` | CREATE | LOW |
| `docs/plans/PHASE_3_SUMMARY.md` | CREATE | LOW |

---

## Success Criteria

### Testing
- [ ] HistoricalMetricsServiceTests: 10+ tests for trigger event storage
- [ ] LargeFileFinderTests: 10+ tests for file scanning logic
- [ ] PermissionsAuditServiceTests: 5+ tests for FDA status
- [ ] TriggerEventTests: 10+ tests for model Codable

### QA
- [ ] Trigger History UI works correctly
- [ ] Large File Finder scans and deletes safely
- [ ] Privacy Audit shows permissions correctly
- [ ] Menu bar quick actions work

### Documentation
- [ ] Phase 3 summary document created

---

## Test Coverage Targets

| Service | Target Tests | Priority |
|---------|-------------|----------|
| HistoricalMetricsService | 10 | HIGH |
| LargeFileFinder | 10 | HIGH |
| PermissionsAuditService | 5 | MEDIUM |
| TriggerEvent model | 10 | HIGH |
| **Total** | **35** | |

---

## Autonomy Budget

| Budget | Limit |
|--------|-------|
| Max files | 5 |
| Max commands | 12 |
| Max retries | 1 |

---

## Dependencies

- All Phase 3 features must be built and working
- XCTest framework
- Swift Package Manager

---

## Out of Scope

- UI automation tests
- Performance benchmarks
- Integration tests with real TCC database

---

## Rollback Plan

**Type:** discard-working-tree

**Action:**
```bash
git checkout -- Tests/
git rm Tests/HistoricalMetricsServiceTests.swift 2>/dev/null || true
git rm Tests/LargeFileFinderTests.swift 2>/dev/null || true
git rm Tests/PermissionsAuditServiceTests.swift 2>/dev/null || true
git rm Tests/TriggerEventTests.swift 2>/dev/null || true
```

---

*Phase 3.5 Planning Complete*
*Ready for /implement*