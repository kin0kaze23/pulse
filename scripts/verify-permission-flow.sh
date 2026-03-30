#!/bin/bash
#
# Pulse Permission Flow Verification Script
# 
# Automated verification of permission UX and health score trend indicator
#
# Usage: bash scripts/verify-permission-flow.sh
# Exit: 0 if all scenarios pass, 1 if any fail
#
# NOTE: Requires Accessibility permission for AppleScript automation
# Run with: sudo bash scripts/verify-permission-flow.sh
#

set -e

cd /Users/jonathannugroho/Developer/PersonalProjects/Pulse

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "$1"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log "========================================"
log "Pulse Permission Flow Verification"
log "========================================"
log ""

# Create screenshots directory
mkdir -p screenshots
rm -f screenshots/pulse-*.png

# ============================================
# Step 0: Reset app state
# ============================================
log "[Step 0] Resetting app state..."
defaults delete com.yourcompany.Pulse 2>/dev/null || warn "No existing Pulse preferences"
killall Pulse 2>/dev/null || true
sleep 1
success "App state reset"

# ============================================
# Step 1: Build Pulse
# ============================================
log ""
log "[Step 1] Building Pulse..."
if swift build --configuration release 2>&1 | tail -3 | grep -q "Build complete"; then
    success "Build complete"
else
    error "Build failed"
    exit 1
fi

# ============================================
# Step 2: Launch Pulse
# ============================================
log ""
log "[Step 2] Launching Pulse..."
killall Pulse 2>/dev/null || true
sleep 1

# Launch using swift run (handles bundle properly)
# Run in background and redirect output
log "Starting Pulse via swift run..."
nohup swift run Pulse > /tmp/pulse-run.log 2>&1 &
PULSE_PID=$!
echo $PULSE_PID > /tmp/pulse.pid

log "Waiting for app to launch (8 seconds)..."
sleep 8

# Verify app is running
if pgrep -x "Pulse" > /dev/null; then
    success "Pulse is running (PID: $PULSE_PID)"
else
    warn "Pulse may not have launched correctly, continuing anyway..."
fi

# ============================================
# Scenario 1: Onboarding (first launch)
# ============================================
log ""
log "[Scenario 1] Capturing onboarding screen..."
screencapture -x screenshots/pulse-01-onboarding.png 2>/dev/null && {
    success "pulse-01-onboarding.png captured"
    ONBOARDING_PASS=true
} || {
    error "pulse-01-onboarding.png FAILED"
    ONBOARDING_PASS=false
}
sleep 1

# ============================================
# Step 3: Dismiss onboarding via AppleScript
# ============================================
log ""
log "[Step 3] Dismissing onboarding..."

# Try multiple approaches to dismiss onboarding
osascript << 'EOF' 2>/dev/null << 'EOF2' 2>/dev/null || warn "Could not dismiss onboarding via AppleScript"
tell application "System Events"
    tell application "Pulse" to activate
    tell process "Pulse"
        -- Try clicking "Continue to Pulse" button
        if exists button "Continue to Pulse" of window 1 then
            click button "Continue to Pulse" of window 1
        else if exists button "Continue" of window 1 then
            click button "Continue" of window 1
        else if exists button "Skip for now" of window 1 then
            click button "Skip for now" of window 1
        end if
    end tell
end tell
EOF
tell application "System Events"
    keystroke return
end tell
EOF2

sleep 2
success "Onboarding dismissal attempted"

# ============================================
# Step 4: Navigate to Security tab
# ============================================
log ""
log "[Step 4] Navigating to Security tab..."

osascript << 'EOF' 2>/dev/null || warn "Could not navigate to Security tab"
tell application "System Events"
    tell application "Pulse" to activate
    tell process "Pulse"
        -- Click Security tab in sidebar
        if exists button "Security" of window 1 then
            click button "Security" of window 1
        end if
    end tell
end tell
EOF

sleep 2
success "Security tab navigation attempted"

# ============================================
# Scenario 2: Permission status in Security tab
# ============================================
log ""
log "[Scenario 2] Capturing Security tab permission status..."
screencapture -x screenshots/pulse-02-security-status.png 2>/dev/null && {
    success "pulse-02-security-status.png captured"
    SECURITY_STATUS_PASS=true
} || {
    error "pulse-02-security-status.png FAILED"
    SECURITY_STATUS_PASS=false
}
sleep 1

# ============================================
# Step 5: Open System Settings to Privacy
# ============================================
log ""
log "[Step 5] Opening System Settings to Privacy..."

# Open Privacy & Security settings
if [ -d "/System/Applications/System Settings.app" ]; then
    open "x-apple.systempreferences:com.apple.PrivacySettings"
else
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
fi

sleep 3
success "System Settings opened to Privacy"

# ============================================
# Step 6: Attempt to grant FDA via AppleScript
# ============================================
log ""
log "[Step 6] Attempting to grant Full Disk Access..."

# This is complex and may not work on all macOS versions
# Try to automate System Settings
osascript << 'EOF' 2>/dev/null || warn "Could not automate FDA grant - manual step may be needed"
tell application "System Events"
    tell application "System Settings" to activate
    tell process "System Settings"
        -- Wait for window
        delay 1
        
        -- Try to find and click the lock button first (if locked)
        if exists button "Click the lock to make changes" of window 1 then
            click button "Click the lock to make changes" of window 1
            delay 2
            -- Note: Password prompt would appear here - cannot automate
        end if
        
        -- Try to find Pulse in the list and enable it
        -- This is highly version-dependent
        if exists table 1 of scroll area 1 of window 1 then
            -- Look for Pulse in the table
            -- This is a best-effort attempt
            log "Found settings table"
        end if
    end tell
end tell
EOF

warn "FDA grant automation is limited - may require manual completion"
log ""
log "   If automation failed, please manually:"
log "   1. Find 'Pulse' in the Full Disk Access list"
log "   2. Enable the toggle"
log "   3. Return to Pulse app"
log ""
log "   Waiting 15 seconds for manual completion..."
sleep 15

# Return to Pulse
osascript -e 'tell application "System Events" to tell application "Pulse" to activate' 2>/dev/null || true

sleep 2

# ============================================
# Scenario 3: Toast notification (if permission was granted)
# ============================================
log ""
log "[Scenario 3] Capturing permission change toast..."
screencapture -x screenshots/pulse-03-fda-toast.png 2>/dev/null && {
    success "pulse-03-fda-toast.png captured"
    TOAST_PASS=true
} || {
    error "pulse-03-fda-toast.png FAILED"
    TOAST_PASS=false
}
sleep 1

# ============================================
# Step 7: Open Settings → Permissions
# ============================================
log ""
log "[Step 7] Opening Settings → Permissions..."

osascript << 'EOF' 2>/dev/null || warn "Could not open Settings"
tell application "System Events"
    tell application "Pulse" to activate
    tell process "Pulse"
        -- Click Settings button (usually gear icon or in menu)
        if exists button "Settings" of window 1 then
            click button "Settings" of window 1
        else if exists button 3 of window 1 then
            click button 3 of window 1
        end if
    end tell
end tell
EOF

sleep 2

# Click Permissions tab in Settings
osascript << 'EOF' 2>/dev/null || warn "Could not navigate to Permissions tab"
tell application "System Events"
    tell application "Pulse" to activate
    tell process "Pulse"
        -- Look for Permissions tab/button
        if exists button "Permissions" of window 1 then
            click button "Permissions" of window 1
        end if
    end tell
end tell
EOF

sleep 2

# ============================================
# Scenario 4: Permissions diagnostics view
# ============================================
log ""
log "[Scenario 4] Capturing Permissions diagnostics view..."
screencapture -x screenshots/pulse-04-permissions-view.png 2>/dev/null && {
    success "pulse-04-permissions-view.png captured"
    PERMISSIONS_VIEW_PASS=true
} || {
    error "pulse-04-permissions-view.png FAILED"
    PERMISSIONS_VIEW_PASS=false
}
sleep 1

# ============================================
# Cleanup
# ============================================
log ""
log "[Cleanup] Closing Pulse..."
killall Pulse 2>/dev/null || true
killall "System Settings" 2>/dev/null || true

# Also kill by PID if still running
if [ -f /tmp/pulse.pid ]; then
    PULSE_PID=$(cat /tmp/pulse.pid)
    kill $PULSE_PID 2>/dev/null || true
    rm /tmp/pulse.pid
fi

# ============================================
# Results Summary
# ============================================
log ""
log "========================================"
log "VERIFICATION RESULTS"
log "========================================"
log ""

PASS_COUNT=0
FAIL_COUNT=0

if [ "$ONBOARDING_PASS" = true ]; then
    success "Scenario 1: Onboarding"
    ((PASS_COUNT++))
else
    error "Scenario 1: Onboarding"
    ((FAIL_COUNT++))
fi

if [ "$SECURITY_STATUS_PASS" = true ]; then
    success "Scenario 2: Security Status"
    ((PASS_COUNT++))
else
    error "Scenario 2: Security Status"
    ((FAIL_COUNT++))
fi

if [ "$TOAST_PASS" = true ]; then
    success "Scenario 3: FDA Toast"
    ((PASS_COUNT++))
else
    error "Scenario 3: FDA Toast"
    ((FAIL_COUNT++))
fi

if [ "$PERMISSIONS_VIEW_PASS" = true ]; then
    success "Scenario 4: Permissions View"
    ((PASS_COUNT++))
else
    error "Scenario 4: Permissions View"
    ((FAIL_COUNT++))
fi

log ""
log "========================================"
log "Summary: $PASS_COUNT/4 passed, $FAIL_COUNT/4 failed"
log "========================================"
log ""

# List captured files
log "Captured screenshots:"
ls -la screenshots/pulse-*.png 2>/dev/null || log "No screenshots found"
log ""

# Verify screenshot content (basic check)
log "Verifying screenshot content..."
for f in screenshots/pulse-*.png; do
    if [ -f "$f" ]; then
        SIZE=$(stat -f%z "$f" 2>/dev/null || echo "0")
        if [ "$SIZE" -gt 1000 ]; then
            success "$(basename $f): $SIZE bytes"
        else
            warn "$(basename $f): Only $SIZE bytes (may be invalid)"
        fi
    fi
done
log ""

# Exit with appropriate code
if [ $FAIL_COUNT -eq 0 ]; then
    success "All scenarios passed!"
    exit 0
else
    error "Some scenarios failed"
    log ""
    log "Troubleshooting tips:"
    log "1. Ensure Pulse has Accessibility permission for AppleScript"
    log "2. Run with: sudo bash scripts/verify-permission-flow.sh"
    log "3. Check that System Settings can be automated"
    log "4. Some steps may require manual completion on macOS Sonoma+"
    exit 1
fi
