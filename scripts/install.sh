#!/usr/bin/env bash
#
# Pulse CLI installer
# Usage: curl -sL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash
#
# This script:
# 1. Checks prerequisites (Swift toolchain, git)
# 2. Clones or updates the Pulse repo
# 3. Builds the CLI
# 4. Links the binary to /usr/local/bin/pulse
#

set -euo pipefail

# Configuration
REPO_URL="https://github.com/kin0kaze23/pulse.git"
REPO_NAME="pulse"
TAG="v0.1.0-alpha"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="pulse"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check prerequisites
check_prerequisites() {
    if ! command -v swift &> /dev/null; then
        error "Swift toolchain not found. Install Xcode or Xcode command line tools."
        error "  xcode-select --install"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        error "git not found. Install Xcode command line tools."
        error "  xcode-select --install"
        exit 1
    fi

    info "Swift: $(swift --version | head -1)"
    info "git: $(git --version)"
}

# Clone or update repo
setup_repo() {
    local clone_dir="$HOME/.pulse-cli"

    if [ -d "$clone_dir/.git" ]; then
        info "Updating existing Pulse CLI installation..."
        cd "$clone_dir"
        git fetch --tags
        git checkout "$TAG" 2>/dev/null || {
            warn "Tag $TAG not found, using latest main"
            git checkout main 2>/dev/null || git checkout master
        }
        git pull --rebase 2>/dev/null || true
    else
        info "Cloning Pulse CLI..."
        git clone --depth 1 --branch "$TAG" "$REPO_URL" "$clone_dir" 2>/dev/null || {
            warn "Tag $TAG not found, cloning main branch"
            git clone --depth 1 "$REPO_URL" "$clone_dir"
        }
        cd "$clone_dir"
    fi

    echo "$clone_dir"
}

# Build CLI
build_cli() {
    local repo_dir="$1"
    cd "$repo_dir"

    info "Building Pulse CLI..."
    swift build --target PulseCLI --target PulseCore -c release

    local binary="$repo_dir/.build/release/PulseCLI"
    if [ ! -f "$binary" ]; then
        # Try alternative binary name
        binary=$(find "$repo_dir/.build/release" -maxdepth 1 -name "pulse" -o -name "PulseCLI" | head -1)
    fi

    if [ ! -f "$binary" ]; then
        error "Build succeeded but binary not found in .build/release/"
        error "Contents:"
        ls -la "$repo_dir/.build/release/" 2>/dev/null || true
        exit 1
    fi

    echo "$binary"
}

# Install binary
install_binary() {
    local binary="$1"

    if [ ! -d "$INSTALL_DIR" ]; then
        info "Creating $INSTALL_DIR..."
        mkdir -p "$INSTALL_DIR"
    fi

    info "Installing pulse to $INSTALL_DIR/$BINARY_NAME..."
    cp "$binary" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"

    # Check if INSTALL_DIR is in PATH
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
        warn "$INSTALL_DIR is not in your PATH"
        warn "Add it by running:"
        warn "  echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
        warn "  source ~/.zshrc"
    fi
}

# Main
main() {
    info "Pulse CLI Installer"
    echo "===================="

    check_prerequisites
    echo ""

    local repo_dir
    repo_dir=$(setup_repo)
    echo ""

    local binary
    binary=$(build_cli "$repo_dir")
    echo ""

    install_binary "$binary"
    echo ""

    info "Installation complete!"
    info ""
    info "Get started:"
    info "  pulse --help"
    info "  pulse analyze"
    info "  pulse doctor"
    info ""
    info "Shell completion (optional):"
    info "  pulse completion zsh > /usr/local/share/zsh/site-functions/_pulse"
}

main "$@"
