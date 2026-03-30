#!/bin/bash
#
# Pulse Distribution Build Script
# Builds, signs, and prepares Pulse.app for distribution
#
# Usage: ./scripts/distribute.sh [--debug]
#
# Environment variables required:
#   - DEVELOPER_TEAM_ID: Your Apple Developer Team ID (e.g., ABC123DEF4)
#   - DEVELOPER_CERTIFICATE: Developer ID Application certificate name (optional, uses automatic if not set)
#
# Optional:
#   - SKIP_NOTARIZE: Set to "1" to skip notarization (for testing only)
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="Pulse"
SCHEME_NAME="Pulse"
BUILD_DIR="$PROJECT_DIR/.build/distribution"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check required environment variables
check_env() {
    log_info "Checking environment variables..."
    
    if [ -z "$DEVELOPER_TEAM_ID" ]; then
        log_error "DEVELOPER_TEAM_ID is not set"
        log_info "Export your Team ID from Apple Developer Portal"
        log_info "Example: export DEVELOPER_TEAM_ID=ABC123DEF4"
        exit 1
    fi
    
    log_success "Environment variables OK"
}

# Clean build directory
clean_build() {
    log_info "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    log_success "Build directory cleaned"
}

# Build archive
build_archive() {
    log_info "Building archive..."
    
    cd "$PROJECT_DIR"
    
    xcodebuild -project Pulse.xcodeproj \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        CODE_SIGN_IDENTITY="${DEVELOPER_CERTIFICATE:-}" \
        DEVELOPMENT_TEAM="$DEVELOPER_TEAM_ID" \
        archive
    
    log_success "Archive created: $ARCHIVE_PATH"
}

# Export from archive
export_archive() {
    log_info "Exporting from archive..."
    
    # Create ExportOptions.plist if it doesn't exist
    if [ ! -f "$SCRIPT_DIR/ExportOptions.plist" ]; then
        log_error "ExportOptions.plist not found in scripts directory"
        log_info "Create it with your Team ID or run: ./scripts/setup-export-options.sh"
        exit 1
    fi
    
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$SCRIPT_DIR/ExportOptions.plist" \
        -allowProvisioningUpdates
    
    log_success "App exported to: $EXPORT_PATH/$PROJECT_NAME.app"
}

# Verify signature
verify_signature() {
    log_info "Verifying code signature..."
    
    codesign -dv --verbose=4 "$EXPORT_PATH/$PROJECT_NAME.app"
    
    if [ $? -eq 0 ]; then
        log_success "Code signature verified"
    else
        log_error "Code signature verification failed"
        exit 1
    fi
}

# Verify entitlements
verify_entitlements() {
    log_info "Verifying entitlements..."
    
    codesign -d --entitlements - "$EXPORT_PATH/$PROJECT_NAME.app"
    
    log_success "Entitlements verified"
}

# Main execution
main() {
    echo "========================================"
    echo "  Pulse Distribution Build"
    echo "========================================"
    echo ""
    
    check_env
    clean_build
    build_archive
    export_archive
    verify_signature
    verify_entitlements
    
    echo ""
    echo "========================================"
    log_success "Distribution build complete!"
    echo "========================================"
    echo ""
    log_info "App location: $EXPORT_PATH/$PROJECT_NAME.app"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Test the app locally"
    log_info "  2. Run ./scripts/notarize.sh to notarize"
    log_info "  3. Run ./scripts/staple.sh to staple ticket"
    log_info ""
}

# Run main
main "$@"
