# Pulse Environment Contract

## Deployment Profile

Profile `D` - Desktop / Local-Only Application

## Source Of Truth

- Local repo: `Pulse`
- Source remote: not yet verified in this workspace audit

## Approved Environments

| Environment | Status | Entry Points | Secrets Source | Notes |
| --- | --- | --- | --- | --- |
| `local` | Active | `swift run Pulse` or `.build/release/Pulse` | None required for normal runtime | Canonical environment today |
| `preview` | Not applicable | None | None | Desktop app repo |
| `staging` | Not applicable | None | None | Desktop app repo |
| `production` | Planned as signed release artifact | Future release binary / app bundle | Keychain, signing assets, or release tooling | Do not assume cloud hosting |

## Rules

- Treat Pulse as a local macOS app until a signed distribution workflow is documented.
- Do not invent Vercel, Railway, or server-hosted environments for this repo.
- If release packaging changes, update this file and `docs/DEPLOYMENT.md`.
