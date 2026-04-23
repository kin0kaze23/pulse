# Tier 1 Setup — Pre-built Binaries + Homebrew Tap

## What was created

| File | Purpose |
|------|---------|
| `.github/workflows/release-cli.yml` | CI workflow that builds universal binary on tag push |
| `homebrew-pulse/Formula/pulse.rb` | Homebrew formula (initial version) |
| `homebrew-pulse/README.md` | Tap repo documentation |

## Setup steps (one-time)

### 1. Create the Homebrew tap repository

```bash
# Create a new public GitHub repo named: homebrew-pulse
# Owner: kin0kaze23
# URL: https://github.com/kin0kaze23/homebrew-pulse
```

The repo must be named `homebrew-pulse` (not `pulse-cli/tap`) because Homebrew convention
uses `homebrew-<name>` for taps, and the install command becomes:
```bash
brew install kin0kaze23/pulse
```

### 2. Push the tap repo contents

```bash
cd /Users/jonathannugroho/Developer/PersonalProjects/homebrew-pulse
git init
git remote add origin git@github.com:kin0kaze23/homebrew-pulse.git
git add .
git commit -m "Initial tap: pulse 0.1.0-alpha"
git branch -M main
git push -u origin main
```

### 3. Create the TAP_TOKEN secret

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Create a new token with:
   - **Repository access**: Only `kin0kaze23/homebrew-pulse`
   - **Permissions**: Contents (read/write)
3. Copy the token value
4. Go to `kin0kaze23/pulse` → Settings → Secrets and variables → Actions
5. Add a new repository secret:
   - **Name**: `TAP_TOKEN`
   - **Value**: <paste token>

### 4. Push a new version tag to trigger the release

The existing `v0.1.0-alpha` tag already exists. To trigger a new release, create a new tag:

```bash
git tag v0.1.1
git push origin v0.1.1
```

This will:
1. Run `swift build` + `swift test` (quality gate)
2. Build arm64 and x86_64 binaries in parallel
3. Create a universal binary with `lipo`
4. Create a GitHub Release with all 3 artifacts
5. Auto-update the Homebrew tap formula with the new version + SHA256

### 5. Verify the release

After the workflow completes (~5-10 minutes):

```bash
brew install kin0kaze23/pulse
pulse --version
pulse doctor
```

## What each release produces

| Artifact | Description |
|----------|-------------|
| `pulse-arm64.zip` | Apple Silicon binary |
| `pulse-x86_64.zip` | Intel binary |
| `pulse-universal.zip` | Universal binary (arm64 + x86_64) |

## How the Homebrew formula works

The formula downloads the universal binary zip, extracts it, and installs `pulse` to `bin/`.
The `bump-homebrew-formula-action` automatically:
1. Downloads the new release artifact
2. Computes SHA256
3. Updates `url` and `sha256` in the formula
4. Commits to the tap repo

No manual formula updates needed after setup.
