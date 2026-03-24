# Pulse — Troubleshooting Guide

> Common issues and solutions

---

## Menu Bar Icon Not Showing

**Problem:** Pulse icon disappears from menu bar after launch.

**Solutions:**
1. Quit Pulse completely (Cmd+Q)
2. Check System Settings → Privacy & Security → Accessibility
3. Ensure Pulse has accessibility permissions
4. Relaunch Pulse

---

## Memory Cleanup Not Working

**Problem:** One-click cleanup button doesn't reduce memory usage.

**Solutions:**
1. Check if you're running as admin user
2. Some processes require sudo — check logs in Console.app
3. Try quitting heavy apps manually first
4. Restart Pulse after major system changes

---

## Health Score Inaccurate

**Problem:** Health score doesn't reflect actual system state.

**Solutions:**
1. Wait 30 seconds for metrics to stabilize
2. Check if all monitors (CPU, Memory, Disk, Network) are active
3. Restart Pulse to refresh metric collection
4. Check Console.app for error logs

---

## Runaway Process Guard False Positives

**Problem:** Legitimate processes being auto-killed.

**Solutions:**
1. Adjust threshold in Settings → Advanced
2. Add process to whitelist
3. Disable auto-kill temporarily
4. Review kill logs before adjusting

---

## Battery Drain

**Problem:** Pulse causing higher than expected battery usage.

**Solutions:**
1. Reduce refresh rate in Settings
2. Disable live charts if not needed
3. Check if historical metrics collection is too frequent
4. Update to latest version

---

## Persistence Scanner False Positives

**Problem:** Legitimate launch agents flagged as suspicious.

**Solutions:**
1. Review scanner results before taking action
2. Check bundle ID and signing info
3. Add to whitelist if verified safe
4. Report false positives to developers

---

## Getting Help

If issues persist:
1. Check Console.app for error logs
2. Run Pulse from Terminal to see stdout/stderr
3. Report issues with logs attached
4. Include macOS version and Pulse version

---

**Last updated:** 2026-03-25
**Version:** 1.0
