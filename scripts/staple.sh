#!/bin/bash
#
# Pulse Stapling Script
# Staples the notarization ticket to the app
#
# Usage: ./scripts/staple.sh
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/distribution"
EXPORT_PATH="$BUILD_DIR/export"
PROJECT_NAME="Pulse"
APP_PATH="$EXPORT_PATH/$PROJECT_NAME.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check app exists
check_app() {
    if [ ! -d "$APP_PATH" ]; then
        log_error "App not found at: $APP_PATH"
        log_info "Run ./scripts/distribute.sh first"
        exit 1
    fi
    log_success "App found"
}

# Staple ticket
staple_ticket() {
    log_info "Stapling notarization ticket..."
    
    xcrun stapler staple "$APP_PATH"
    
    if [ $? -eq 0 ]; then
        log_success "Ticket stapled successfully"
    else
        log_error "Stapling failed"
        exit 1
    fi
}

# Verify staple
verify_staple() {
    log_info "Verifying stapled ticket..."
    
    spctl -a -v "$APP_PATH"
    
    if [ $? -eq 0 ]; then
        log_success "App verification passed"
    else
        log_warning "App verification returned non-zero (may still be valid)"
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "  Pulse Stapling"
    echo "========================================"
    echo ""
    
    check_app
    staple_ticket
    verify_staple
    
    echo ""
    echo "========================================"
    log_success "Stapling complete!"
    echo "========================================"
    echo ""
    log_info "Your app is now ready for distribution"
    log_info "Location: $APP_PATH"
    log_info ""
}

main "$@"
