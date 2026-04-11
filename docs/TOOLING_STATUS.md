# Tooling Status

> **Project:** Pulse
> **Last updated:** 2026-04-06
> **Stage:** Production (App Store)
> **Payment model:** Free-only

---

## Project Overview

| Field | Value |
|-------|-------|
| **Purpose** | Native macOS menu bar system monitor |
| **Status** | active |
| **Maturity stage** | Production (App Store) |
| **Payment model:** | Free-only |

---

## Stack Summary

| Layer | Technology | Status | Notes |
|-------|------------|--------|-------|
| **Package Manager** | Swift SPM | ✅ Configured | Native Swift |
| **Frontend** | SwiftUI | ✅ Configured | macOS native UI |
| **Backend** | None | ✅ N/A | Native app |
| **Database** | None | ✅ N/A | In-memory metrics |
| **ORM** | None | ✅ N/A | No database |
| **Auth** | None | ✅ N/A | Local app |
| **Deployment** | App Store | ✅ Configured | macOS app |
| **Secrets** | .env files | ⚠️ Basic | Build-time only |
| **Testing** | XCTest | ❓ Unknown | Verify test setup |
| **CI/CD** | GitHub Actions | ✅ Configured | Swift build |
| **Monitoring** | None | ❌ Missing | Not configured |
| **Task Tracking** | GitHub Projects | ✅ Configured | Free tier |

---

## Detailed Status

### Free Tools in Use

| Tool | Purpose | Configuration Status |
|------|---------|---------------------|
| GitHub | Code hosting, CI/CD | ✅ Configured |
| GitHub Actions | CI/CD pipeline | ✅ Configured |
| Xcode | Build + test | ✅ Configured |
| App Store Connect | Distribution | ✅ Configured |

### Paid Tools in Use

| Tool | Purpose | Cost | Justification |
|------|---------|------|---------------|
| Apple Developer Program | App Store distribution | $99/year | Required for App Store |

---

## Intentionally Not Used

| Tool | Why Not Used |
|------|--------------|
| Web frameworks | Native macOS app |
| Database | In-memory system metrics |
| Auth | Local app; no accounts |
| Web monitoring | App Store analytics only |

---

## Biggest Gap

**No in-app telemetry** — App Store Connect provides download/crash data, but no usage analytics. Consider:
- Firebase Analytics (free, but Google)
- Self-hosted PostHog (more setup)
- App Store Connect only (simplest)

---

## Recommended Next Step

**Document current App Store Connect usage (15 min)** — verify what metrics are already available before adding new tools. May be "good enough" for a simple menu bar app.

---

## Notes / Intentional Deviations

- **Native Swift:** Only non-web project in portfolio
- **App Store only:** No web deployment
- **$99 Apple Developer:** Only paid tool in entire portfolio

---

## Quick Links

| Link | Purpose |
|------|---------|
| `README.md` | Project overview |
| `AGENTS.md` | Agent instructions |
| `.env.example` | Environment template |

---

## Stage Exit Criteria

| Current Stage | Next Stage | Requirements |
|---------------|------------|--------------|
| Production | Ongoing | - App Store reviews monitored<br>- Crash-free rate > 99%<br>- Feature requests tracked in GitHub Issues |
