#!/bin/bash
#
# Pulse Notarization Script
# Submits the app to Apple for notarization
#
# Usage: ./scripts/notarize.sh
#
# Environment variables required:
#   - APPLE_ID: Your Apple ID email (e.g., your@email.com)
#   - APPLE_PASSWORD: App-specific password (not your regular password)
#   - DEVELOPER_TEAM_ID: Your Apple Developer Team ID
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/distribution"
EXPORT_PATH="$BUILD_DIR/export"
PROJECT_NAME="Pulse"
APP_PATH="$EXPORT_PATH/$PROJECT_NAME.app"
ZIP_PATH="$BUILD_DIR/$PROJECT_NAME.zip"

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

# Check environment
check_env() {
    log_info "Checking environment variables..."
    
    if [ -z "$APPLE_ID" ]; then
        log_error "APPLE_ID is not set"
        log_info "Example: export APPLE_ID=your@email.com"
        exit 1
    fi
    
    if [ -z "$APPLE_PASSWORD" ]; then
        log_error "APPLE_PASSWORD is not set"
        log_info "Create an app-specific password at appleid.apple.com"
        log_info "Example: export APPLE_PASSWORD=xxxx-xxxx-xxxx-xxxx"
        exit 1
    fi
    
    if [ -z "$DEVELOPER_TEAM_ID" ]; then
        log_error "DEVELOPER_TEAM_ID is not set"
        log_info "Example: export DEVELOPER_TEAM_ID=ABC123DEF4"
        exit 1
    fi
    
    log_success "Environment variables OK"
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

# Create ZIP for notarization
create_zip() {
    log_info "Creating ZIP for notarization..."
    
    cd "$EXPORT_PATH"
    zip -r -X "$ZIP_PATH" "$PROJECT_NAME.app"
    
    log_success "ZIP created: $ZIP_PATH"
}

# Submit for notarization
submit_notarization() {
    log_info "Submitting for notarization..."
    
    # Submit using notarytool
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_PASSWORD" \
        --team-id "$DEVELOPER_TEAM_ID" \
        --wait
    
    if [ $? -eq 0 ]; then
        log_success "Notarization submitted and completed"
    else
        log_error "Notarization failed"
        exit 1
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "  Pulse Notarization"
    echo "========================================"
    echo ""
    
    check_env
    check_app
    create_zip
    submit_notarization
    
    echo ""
    echo "========================================"
    log_success "Notarization complete!"
    echo "========================================"
    echo ""
    log_info "Next step: Run ./scripts/staple.sh to staple the notarization ticket"
    log_info ""
}

main "$@"
