# Pulse Security Roadmap

> Separating Pulse Core (MIT) from Security Extension (GPL-compatible consideration)

---

## Architecture Decision: Two-Tier Security

Pulse has fundamentally different security capabilities that warrant architectural separation:

### Tier 1: Pulse Core (MIT License)
**User-space monitoring and cleanup - no special privileges required**

- System monitoring (memory, CPU, disk, network)
- Cache cleanup (Xcode, npm, Docker, browsers)
- Process management (view, kill, auto-kill)
- File-based persistence scanning (LaunchAgents, LaunchDaemons)
- Health score and recommendations
- Developer profiles

**Characteristics:**
- No special entitlements required
- Works with standard macOS permissions
- Can be distributed via App Store (with modifications)
- Compatible with MIT license

### Tier 2: Pulse Security Extension (GPL-Compatible License Consideration)
**Kernel-level security - requires system extension**

- Endpoint Security framework integration
- Real-time process monitoring
- Network traffic analysis
- Malware signature scanning
- Behavioral threat detection
- Deep TCC database access

**Characteristics:**
- Requires system extension entitlement (Apple approval)
- Requires Full Disk Access
- Cannot be distributed via App Store
- May need GPL-compatible license due to viral dependencies

---

## Reference Tools Analysis

### Objective-See Tools (Free, Closed Source)

| Tool | Purpose | License | Integration Potential |
|------|---------|---------|----------------------|
| **KnockKnock** | Persistence scanner | Closed | Reference for scan locations |
| **ReiKey** | Keylogger detection | Closed | Reference for event tap detection |
| **BlockBlock** | Real-time persistence blocking | Closed | Reference for Endpoint Security |
| **TaskExplorer** | Task/Process explorer | Closed | Reference for process info |
| **KnockKnock** | Login items scanner | Closed | Reference for persistence locations |

**License Risk:** None (closed source, used as reference only)

### Stats (MIT License)

| Feature | Purpose | License | Integration Potential |
|---------|---------|---------|----------------------|
| SMC reading | Temperature sensors | MIT | Can reuse SMC key definitions |
| Menu bar monitoring | System metrics | MIT | Architecture reference |

**License Risk:** None (MIT compatible)

### macOS-Cleanup Scripts (MIT License)

| Feature | Purpose | License | Integration Potential |
|---------|---------|---------|----------------------|
| Cleanup definitions | Cache locations | MIT | Can reuse path definitions |

**License Risk:** None (MIT compatible)

### Santa (Apache 2.0 License)

| Feature | Purpose | License | Integration Potential |
|---------|---------|---------|----------------------|
| Binary authorization | Allow/deny execution | Apache 2.0 | Reference for policy enforcement |
| Event logging | Security events | Apache 2.0 | Reference for event schema |

**License Risk:** Low (Apache 2.0 is permissive)

### osquery (Apache 2.0 + GPL)

| Feature | Purpose | License | Integration Potential |
|---------|---------|---------|----------------------|
| System telemetry | SQL-based queries | Apache 2.0 + GPL | **HIGH RISK** - avoid direct integration |

**License Risk:** **HIGH** - GPL components would viral-license Pulse

---

## License Compatibility Analysis

### Current Pulse License: MIT

**Compatible with:**
- ✅ MIT
- ✅ Apache 2.0
- ✅ BSD
- ✅ ISC
- ✅ Proprietary (closed source)

**NOT Compatible with:**
- ❌ GPL v2 (viral)
- ❌ GPL v3 (viral)
- ❌ AGPL (viral, network clause)
- ❌ LGPL (viral for linked code)

### Recommendation: Stay MIT

**Reasons:**
1. Pulse Core has no GPL dependencies
2. Reference tools are used for inspiration, not code reuse
3. MIT allows commercial use and App Store distribution
4. Contributors prefer permissive licenses
5. No obligation to open-source Security Extension

### If Security Extension Uses GPL Code:

**Options:**
1. **Dual-license:** Pulse Core (MIT) + Security Extension (GPL)
2. **Separate repo:** Keep GPL code in isolated repository
3. **Plugin architecture:** Security Extension as separate binary
4. **Avoid GPL:** Find MIT/Apache alternatives

---

## Security Extension Architecture (Future)

### Endpoint Security Integration

```
┌─────────────────────────────────────────────────────────┐
│              Pulse Security Extension                    │
│  (System Extension - requires Apple approval)           │
├─────────────────────────────────────────────────────────┤
│  Endpoint Security Framework                             │
│  ├─ ES_EVENT_TYPE_AUTH_EXEC                              │
│  ├─ ES_EVENT_TYPE_AUTH_OPEN                              │
│  ├─ ES_EVENT_TYPE_AUTH_KEXT                              │
│  └─ ES_EVENT_TYPE_AUTH_LAUNCH                            │
├─────────────────────────────────────────────────────────┤
│  Real-Time Event Processor                               │
│  ├─ Process tree tracking                                │
│  ├─ File access monitoring                               │
│  └─ Network connection tracking                          │
├─────────────────────────────────────────────────────────┤
│  Threat Detection Engine                                 │
│  ├─ Signature matching (YARA rules)                      │
│  ├─ Behavioral analysis                                  │
│  └─ Anomaly detection                                    │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│              Pulse Core (MIT)                            │
│  (Regular App - no special entitlements)                │
├─────────────────────────────────────────────────────────┤
│  UI and Visualization                                    │
│  System Monitoring (non-privileged)                      │
│  Cache Cleanup                                           │
│  Process Management                                      │
└─────────────────────────────────────────────────────────┘
```

### Development Phases

**Phase 1: Pulse Core (Current)**
- ✅ System monitoring
- ✅ Cache cleanup
- ✅ Process management
- ✅ File-based persistence scanning
- License: MIT

**Phase 2: Enhanced Core (6-12 months)**
- [ ] Historical trend analysis
- [ ] Swift Charts integration
- [ ] Disk treemap visualization
- [ ] Improved Apple Silicon sensor support
- License: MIT

**Phase 3: Security Extension Prototype (12-18 months)**
- [ ] Endpoint Security framework integration
- [ ] System extension entitlement application
- [ ] Real-time event processing
- [ ] Basic threat detection
- License: **Decision needed** (MIT vs GPL-compatible)

**Phase 4: Full Security Suite (18-24 months)**
- [ ] YARA rule integration
- [ ] Behavioral analysis
- [ ] Network monitoring
- [ ] Cloud threat intelligence
- License: **Decision needed** (may be GPL due to YARA)

---

## YARA Integration Analysis

### YARA License: GPL

**Problem:** YARA (popular malware scanning engine) is GPL-licensed.

**Implications:**
- Direct integration would require Pulse to be GPL-licensed
- Viral licensing affects entire codebase
- Cannot be distributed via App Store

**Alternatives:**
1. **Separate binary:** YARA scanner as standalone tool
2. **Cloud scanning:** Send hashes to cloud service (privacy concerns)
3. **Custom rules:** Implement simple pattern matching (limited)
4. **Avoid:** Focus on persistence detection, not malware scanning

**Recommendation:** Avoid YARA integration. Focus on persistence detection (KnockKnock-style) rather than malware scanning.

---

## Decision Matrix

| Feature | License | Complexity | Apple Approval | Recommendation |
|---------|---------|------------|----------------|----------------|
| **Pulse Core** | MIT | Low | None | ✅ Proceed |
| **File Watchers** | MIT | Low | None | ✅ Proceed |
| **Persistence Scanner** | MIT | Medium | None | ✅ Proceed |
| **Endpoint Security** | TBD | High | Required | ⚠️ Phase 3 |
| **YARA Scanning** | GPL | Medium | None | ❌ Avoid |
| **Network Monitoring** | MIT | High | Network Extension | ⚠️ Phase 4 |
| **Behavioral Analysis** | MIT | Very High | None | ⚠️ Phase 4 |

---

## Final Recommendation

### Stay MIT for Pulse Core

**Reasons:**
1. No GPL dependencies in current codebase
2. Reference tools used for inspiration only (not code reuse)
3. MIT allows maximum adoption and contribution
4. App Store distribution remains possible
5. Commercial use allowed (consulting, enterprise)

### Security Extension: Separate Repository

**Structure:**
- `pulse-core` (MIT) - Main repository
- `pulse-security-extension` (TBD) - Separate repository
- Clear API boundary between Core and Extension
- Extension is optional add-on

**License Decision for Extension:**
- If no GPL code: MIT
- If YARA required: GPL v3 (separate repo)
- If Santa integration: Apache 2.0

### Immediate Actions

1. **Document license boundaries** in CONTRIBUTING.md
2. **Avoid GPL code** in main repository
3. **Create security-extension** branch for experimentation
4. **Apply for Endpoint Security entitlement** (6-12 month process)
5. **Consult legal counsel** before GPL integration

---

*Last updated: March 27, 2026*
*Version: 1.1 (pre-release)*
