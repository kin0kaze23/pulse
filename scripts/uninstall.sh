#!/usr/bin/env bash
#
# Pulse CLI uninstaller
# Usage: curl -sL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/uninstall.sh | bash
#
# This script:
# 1. Removes the pulse binary from PATH
# 2. Removes shell completion files
# 3. Removes cloned source directory (~/.pulse-cli)
# 4. Does NOT remove user data (settings, logs, cache)
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if pulse is installed
if ! command -v pulse &> /dev/null; then
    warn "Pulse CLI is not installed (not found in PATH)"
fi

# Confirm
echo "This will remove Pulse CLI from your system."
echo "User data (settings, logs, audit log) will be preserved."
echo ""
echo "The following will be removed:"
echo "  - pulse binary (wherever it is in PATH)"
echo "  - Shell completion files"
echo "  - Source directory: ~/.pulse-cli"
echo ""
echo "The following will be preserved:"
echo "  - ~/Library/Application Support/Pulse/"
echo "  - ~/Library/Caches/Pulse/"
echo "  - ~/Library/Logs/Pulse/"
echo ""

read -rp "Continue? [y/N] " response
response=${response:-N}
case "$response" in
    [Yy]*)
        info "Uninstalling Pulse CLI..."
        ;;
    *)
        info "Cancelled."
        exit 0
        ;;
esac

# Remove binary
pulse_path=""
if command -v pulse &> /dev/null; then
    pulse_path=$(command -v pulse)
    info "Removing pulse binary: $pulse_path"
    rm -f "$pulse_path"
fi

# Also check common locations in case PATH is stale
for dir in /usr/local/bin /opt/homebrew/bin "$HOME/.local/bin"; do
    if [ -f "$dir/pulse" ]; then
        info "Removing: $dir/pulse"
        rm -f "$dir/pulse"
    fi
done

# Remove shell completion
for f in /usr/local/share/zsh/site-functions/_pulse "$HOME/.zsh/completions/_pulse"; do
    if [ -f "$f" ]; then
        info "Removing completion: $f"
        rm -f "$f"
    fi
done

for f in /etc/bash_completion.d/pulse; do
    if [ -f "$f" ]; then
        info "Removing completion: $f"
        rm -f "$f"
    fi
done

# Remove source directory
if [ -d "$HOME/.pulse-cli" ]; then
    info "Removing source directory: $HOME/.pulse-cli"
    rm -rf "$HOME/.pulse-cli"
fi

# Remove backup files
for f in /usr/local/bin/pulse.bak /opt/homebrew/bin/pulse.bak "$HOME/.local/bin/pulse.bak"; do
    if [ -f "$f" ]; then
        rm -f "$f"
    fi
done

echo ""
info "Pulse CLI uninstalled."
echo ""
info "User data preserved in:"
info "  ~/Library/Application Support/Pulse/"
info "  ~/Library/Caches/Pulse/"
info "  ~/Library/Logs/Pulse/"
echo ""
info "To reinstall:"
info "  curl -sL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash"
