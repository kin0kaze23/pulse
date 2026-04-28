#!/usr/bin/env bash
#
# Pulse CLI installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/install.sh | bash -s -- --yes
#
# Options:
#   --yes, -y       Non-interactive mode (auto-upgrade if existing install found)
#   --tag <version> Install a specific version instead of the latest tag
#   --prefix <dir>  Install binary to a custom directory
#
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/uninstall.sh | bash
#

set -euo pipefail

# Configuration
REPO_URL="https://github.com/kin0kaze23/pulse.git"
DEFAULT_TAG="v0.3.7"
TAG=""
PREFIX=""
YES_MODE=false

# Colors (only when stdout is a TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BOLD=''
    NC=''
fi

info()    { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
header()  { echo -e "${BOLD}$*${NC}" >&2; }

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y)   YES_MODE=true; shift ;;
        --tag)      TAG="$2"; shift 2 ;;
        --prefix)   PREFIX="$2"; shift 2 ;;
        *)          warn "Unknown argument: $1"; shift ;;
    esac
done
TAG="${TAG:-$DEFAULT_TAG}"

# Detect architecture
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        arm64)    info "Architecture: Apple Silicon (arm64)" ;;
        x86_64)   info "Architecture: Intel (x86_64)" ;;
        *)        warn "Unknown architecture: $arch (continuing anyway)" ;;
    esac
}

# Try Homebrew install first
try_brew_install() {
    if ! command -v brew &> /dev/null; then
        return 1
    fi

    # Check if pulse is already available via a tap
    if brew info pulse 2>/dev/null | grep -q "pulse"; then
        info "Pulse is available via Homebrew."
        if $YES_MODE; then
            info "Installing via brew..."
            brew install pulse
            return 0
        else
            echo "" >&2
            read -rp "Install via Homebrew? [Y/n] " response
            response=${response:-Y}
            if [[ "$response" =~ ^[Yy] ]]; then
                info "Installing via brew..."
                brew install pulse
                return 0
            fi
        fi
    fi
    return 1
}

# Select install directory
select_install_dir() {
    if [ -n "$PREFIX" ]; then
        mkdir -p "$PREFIX"
        echo "$PREFIX"
        return 0
    fi

    # Try /usr/local/bin
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
        return 0
    fi

    # Try /opt/homebrew/bin (Apple Silicon Homebrew)
    if [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
        echo "/opt/homebrew/bin"
        return 0
    fi

    # Fallback: ~/.local/bin (user-writable, no sudo)
    local local_bin="$HOME/.local/bin"
    mkdir -p "$local_bin"
    echo "$local_bin"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v swift &> /dev/null; then
        error "Swift toolchain not found."
        error "Install Xcode command line tools:"
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

        if pulse --version &> /dev/null; then
            info "Current: $(pulse --version 2>/dev/null)"
            info "Target:  Pulse CLI $TAG"
        fi

        if ! $YES_MODE; then
            echo "" >&2
            read -rp "Upgrade Pulse? [Y/n] " response
            response=${response:-Y}
            case "$response" in
                [Yy]*) info "Upgrading..." ;;
                *)     info "Installation cancelled."; exit 0 ;;
            esac
        fi
    fi
}

# Clone or update repo
setup_repo() {
    local clone_dir="$HOME/.pulse-cli"

    if [ -d "$clone_dir/.git" ]; then
        info "Updating existing Pulse CLI source..."
        cd "$clone_dir"
        git fetch --tags
        if git checkout "$TAG" 2>/dev/null; then
            info "Checked out tag: $TAG"
        else
            warn "Tag $TAG not found, using latest main"
            git checkout main 2>/dev/null || git checkout master
        fi
        git pull --rebase 2>/dev/null || true
    else
        info "Cloning Pulse CLI..."
        if git clone --depth 1 --branch "$TAG" "$REPO_URL" "$clone_dir" 2>/dev/null; then
            info "Cloned tag: $TAG"
        else
            warn "Tag $TAG not found, cloning main branch"
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

    info "Building Pulse CLI (release mode)..."
    swift build --product pulse -c release >&2

    local binary="$repo_dir/.build/release/pulse"
    if [ ! -f "$binary" ]; then
        error "Build succeeded but binary not found: $binary"
        exit 1
    fi

    info "Binary: $binary"
    echo "$binary"
}

# Install binary
install_binary() {
    local binary="$1"
    local install_dir="$2"
    local dest="$install_dir/pulse"

    info "Installing pulse to $dest..."

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

    # PATH check
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^${install_dir}$"; then
        warn "$install_dir is not in your PATH"
        warn "Add it by running:"
        warn "  echo 'export PATH=\"${install_dir}:\$PATH\"' >> ~/.zshrc"
        warn "  source ~/.zshrc"
    fi
}

# Install shell completion
install_completion() {
    local install_dir="$1"
    local pulse_bin="$install_dir/pulse"

    # Zsh completion
    local zsh_dir="/usr/local/share/zsh/site-functions"
    if [ -d "$zsh_dir" ] && [ -w "$zsh_dir" ]; then
        "$pulse_bin" completion zsh > "$zsh_dir/_pulse" 2>/dev/null || true
        info "Installed zsh completion: $zsh_dir/_pulse"
    else
        local user_zsh="${ZDOTDIR:-$HOME}/.zsh/completions"
        mkdir -p "$user_zsh"
        "$pulse_bin" completion zsh > "$user_zsh/_pulse" 2>/dev/null || true
        info "Installed zsh completion: $user_zsh/_pulse"
        info "Add to ~/.zshrc: fpath=(\"$user_zsh\" \$fpath)"
    fi

    # Bash completion
    local bash_dir="/etc/bash_completion.d"
    if [ -d "$bash_dir" ] && [ -w "$bash_dir" ]; then
        "$pulse_bin" completion bash > "$bash_dir/pulse" 2>/dev/null || true
        info "Installed bash completion: $bash_dir/pulse"
    fi
}

# Main
main() {
    header "Pulse CLI Installer"
    echo "========================================" >&2
    echo "" >&2

    # Try Homebrew first
    if try_brew_install; then
        echo "" >&2
        echo "========================================" >&2
        header "Installation complete!"
        echo "" >&2
        info "Get started:"
        info "  pulse --help"
        info "  pulse analyze"
        info "  pulse doctor"
        exit 0
    fi

    detect_arch
    check_prerequisites
    check_existing
    echo "" >&2

    local install_dir
    install_dir=$(select_install_dir)
    info "Install directory: $install_dir"
    echo "" >&2

    local repo_dir
    repo_dir=$(setup_repo)
    echo "" >&2

    local binary
    binary=$(build_cli "$repo_dir")
    echo "" >&2

    install_binary "$binary" "$install_dir"
    echo "" >&2

    install_completion "$install_dir"
    echo "" >&2

    echo "========================================" >&2
    header "Installation complete!"
    echo "" >&2
    info "Get started:"
    info "  pulse --help"
    info "  pulse analyze"
    info "  pulse doctor"
    info ""
    info "Upgrade: run this installer again"
    info "Uninstall: curl -fsSL https://raw.githubusercontent.com/kin0kaze23/pulse/main/scripts/uninstall.sh | bash"
    echo ""
}

main "$@"
