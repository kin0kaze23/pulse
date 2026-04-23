# Pulse Agent Rules

## Environment Model

- Local-only desktop app.
- No cloud deployment assumptions.
- Production means a signed release artifact, not a server deploy.

## Required Verification

```bash
swift build
swift test
swift build -c release
```

## Safety Rules

- Treat cleanup, permissions, and process-kill changes as high-risk.
- Keep app-bundle outputs out of source control unless the repo owner explicitly wants them.
- Update release docs whenever distribution, signing, or permissions requirements change.
