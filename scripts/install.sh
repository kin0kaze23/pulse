#!/usr/bin/env bash
#
# Pulse CLI installer
# Usage: curl -sL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash
#
# This script:
# 1. Checks prerequisites (Swift toolchain, git)
# 2. Detects architecture (Apple Silicon vs Intel)
# 3. Selects the best install directory
# 4. Clones or updates the Pulse repo
# 5. Builds the CLI
# 6. Installs the binary
#
# Uninstall: pulse uninstall
#   Or run: curl -sL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/uninstall.sh | bash
#

set -euo pipefail

# Configuration
REPO_URL="https://github.com/kin0kaze23/pulse.git"
TAG="v0.1.0-alpha"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        arm64)
            info "Architecture: Apple Silicon (arm64)"
            ;;
        x86_64)
            info "Architecture: Intel (x86_64)"
            ;;
        *)
            warn "Unknown architecture: $arch (continuing anyway)"
            ;;
    esac
}

# Select the best install directory
select_install_dir() {
    # Priority: Homebrew dir → /usr/local/bin → ~/.local/bin
    # Check if Homebrew pulse exists (upgrade scenario)
    local brew_pulse=""
    if command -v brew &> /dev/null; then
        brew_pulse=$(brew --prefix 2>/dev/null)/bin/pulse
        if [ -f "$brew_pulse" ]; then
            echo "$(brew --prefix 2>/dev/null)/bin"
            return 0
        fi
    fi

    # Try /usr/local/bin (standard on Intel, may exist on Apple Silicon)
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
        return 0
    fi

    # Try /opt/homebrew/bin (Apple Silicon Homebrew)
    if [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
        echo "/opt/homebrew/bin"
        return 0
    fi

    # Fallback: ~/.local/bin (user-writable, no sudo needed)
    local local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    echo "$local_bin"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v swift &> /dev/null; then
        error "Swift toolchain not found."
        error "Install Xcode or Xcode command line tools:"
        error "  xcode-select --install"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        error "git not found."
        error "Install Xcode command line tools:"
        error "  xcode-select --install"
        exit 1
    fi

    info "Swift: $(swift --version | head -1)"
    info "git: $(git --version)"
}

# Check for existing installation
check_existing() {
    if command -v pulse &> /dev/null; then
        local existing_path
        existing_path=$(command -v pulse)
        info "Existing Pulse found: $existing_path"

        # Try to get existing version
        if pulse --version &> /dev/null; then
            local existing_version
            existing_version=$(pulse --version 2>/dev/null)
            info "Current version: $existing_version"
            info "Target version: $TAG"
            echo ""
        fi

        read -rp "Upgrade Pulse? [Y/n] " response
        response=${response:-Y}
        case "$response" in
            [Yy]*)
                info "Upgrading..."
                ;;
            *)
                info "Installation cancelled."
                exit 0
                ;;
        esac
    fi
}

# Clone or update repo
setup_repo() {
    local clone_dir="$HOME/.pulse-cli"

    if [ -d "$clone_dir/.git" ]; then
        info "Updating existing Pulse CLI source..." >&2
        cd "$clone_dir"
        git fetch --tags
        if git checkout "$TAG" 2>/dev/null; then
            info "Checked out tag: $TAG" >&2
        else
            warn "Tag $TAG not found, using latest main" >&2
            git checkout main 2>/dev/null || git checkout master
        fi
        git pull --rebase 2>/dev/null || true
    else
        info "Cloning Pulse CLI..." >&2
        if git clone --depth 1 --branch "$TAG" "$REPO_URL" "$clone_dir" 2>/dev/null; then
            info "Cloned tag: $TAG" >&2
        else
            warn "Tag $TAG not found, cloning main branch" >&2
            git clone --depth 1 "$REPO_URL" "$clone_dir"
        fi
        cd "$clone_dir"
    fi

    echo "$clone_dir"
}

# Build CLI
build_cli() {
    local repo_dir="$1"
    cd "$repo_dir"

    info "Building Pulse CLI (release mode)..." >&2
    swift build --target PulseCLI --target PulseCore -c release >&2

    # Find the binary — SPM names it after the product, not the target
    local binary
    binary=$(find "$repo_dir/.build/release" -maxdepth 1 -type f \( -name "pulse" -o -name "PulseCLI" \) | head -1)

    if [ ! -f "$binary" ]; then
        error "Build succeeded but binary not found in .build/release/" >&2
        error "Contents:" >&2
        ls -la "$repo_dir/.build/release/" 2>/dev/null || true >&2
        exit 1
    fi

    info "Binary: $binary" >&2
    echo "$binary"
}

# Install binary
install_binary() {
    local binary="$1"
    local install_dir="$2"
    local dest="$install_dir/pulse"

    info "Installing pulse to $dest..."

    # If destination exists, back it up
    if [ -f "$dest" ]; then
        local backup="${dest}.bak"
        cp "$dest" "$backup"
        info "Backed up existing binary to ${backup}"
    fi

    cp "$binary" "$dest"
    chmod +x "$dest"

    # Verify installation
    if "$dest" --version &> /dev/null; then
        info "Installed: $($dest --version)"
    else
        warn "Binary installed but --version check failed"
    fi

    # Check if install dir is in PATH
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^${install_dir}$"; then
        warn "$install_dir is not in your PATH"
        warn "Add it by running:"
        warn "  echo 'export PATH=\"${install_dir}:\$PATH\"' >> ~/.zshrc"
        warn "  source ~/.zshrc"
    else
        info "Pulse is in your PATH"
    fi
}

# Install shell completion
install_completion() {
    local install_dir="$1"
    local pulse_bin="$install_dir/pulse"

    # Zsh completion
    local zsh_dir="/usr/local/share/zsh/site-functions"
    if [ -d "$zsh_dir" ] && [ -w "$zsh_dir" ]; then
        "$pulse_bin" completion zsh > "$zsh_dir/_pulse" 2>/dev/null
        info "Installed zsh completion: $zsh_dir/_pulse"
    else
        # User-level completion
        local user_zsh="${ZDOTDIR:-$HOME}/.zsh/completions"
        mkdir -p "$user_zsh"
        "$pulse_bin" completion zsh > "$user_zsh/_pulse" 2>/dev/null
        info "Installed zsh completion: $user_zsh/_pulse"
        info "Add to ~/.zshrc: fpath=(\"$user_zsh\" \$fpath)"
    fi

    # Bash completion
    local bash_dir="/etc/bash_completion.d"
    if [ -d "$bash_dir" ] && [ -w "$bash_dir" ]; then
        "$pulse_bin" completion bash > "$bash_dir/pulse" 2>/dev/null
        info "Installed bash completion: $bash_dir/pulse"
    fi
}

# Main
main() {
    echo ""
    info "${BOLD}Pulse CLI Installer${NC}"
    echo "========================================"
    echo ""

    detect_arch
    check_prerequisites
    check_existing
    echo ""

    local install_dir
    install_dir=$(select_install_dir)
    info "Install directory: $install_dir"
    echo ""

    local repo_dir
    repo_dir=$(setup_repo)
    echo ""

    local binary
    binary=$(build_cli "$repo_dir")
    echo ""

    install_binary "$binary" "$install_dir"
    echo ""

    install_completion "$install_dir"
    echo ""

    echo "========================================"
    info "${BOLD}Installation complete!${NC}"
    echo ""
    info "Get started:"
    info "  pulse --help"
    info "  pulse analyze"
    info "  pulse doctor"
    info ""
    info "Upgrade: run this installer again"
    info "Uninstall: pulse uninstall"
    info "  or: curl -sL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/uninstall.sh | bash"
    echo ""
}

main "$@"
