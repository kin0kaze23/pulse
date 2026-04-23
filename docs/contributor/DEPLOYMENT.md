# Pulse Deployment Guide

## Current Approved Model

Pulse is currently a local macOS application built from source.
There is no approved cloud deployment model.

## Local Build And Run

```bash
swift build
swift test
swift build -c release
open .build/release/Pulse
```

## Release Candidate Checks

- `swift build`
- `swift test`
- `swift build -c release`
- manual launch and menu bar verification

## Future Distribution

When the repo is ready for wider distribution, the approved path should be:

1. build a release artifact
2. sign and notarize it
3. publish a versioned release artifact

Until those steps are documented and automated, treat release builds as operator-only.

## Smoke Checks

- app launches without crashing
- menu bar item appears
- dashboard loads
- cleanup preview and alert flows still work

## Rollback

Rollback means returning to the previous signed or known-good release artifact.
Do not distribute ad-hoc local binaries as production releases.
