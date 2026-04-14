import XCTest
@testable import Pulse

/// Integration tests for safety-critical features
final class SafetyFeaturesTests: XCTestCase {

    // MARK: - Path Safety Tests

    func testProtectedSystemPaths() {
        // Verify critical system paths cannot be deleted
        let protectedPaths = [
            "/System/Library",
            "/bin/bash",
            "/usr/bin",
            "/var/log",
            "/etc/hosts",
            "/Library/LaunchDaemons",
            "/Applications/Safari.app"
        ]
        
        for path in protectedPaths {
            XCTAssertFalse(
                TestSafetyHelpers.isPathSafeToDelete(path),
                "Path should be protected: \(path)"
            )
        }
    }
    
    func testAllowedCleanupPaths() {
        // Verify user cache directories can be cleaned
        let allowedPaths = [
            "/Users/test/Library/Caches/com.apple.Safari",
            "/Users/test/Library/Developer/Xcode/DerivedData",
            "/Users/test/Library/Caches/Homebrew",
            "/var/folders/xx/xyz123/T"
        ]
        
        for path in allowedPaths {
            XCTAssertTrue(
                TestSafetyHelpers.isPathSafeToDelete(path),
                "Path should be allowed: \(path)"
            )
        }
    }
    
    func testUserHomeProtection() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Home directory itself should be protected
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete(homeDir))

        // Documents, Desktop, and Downloads folders should be protected
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete(homeDir + "/Documents"))
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete(homeDir + "/Desktop"))
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete(homeDir + "/Downloads"))

        // But individual files inside Downloads can be cleaned
        XCTAssertTrue(TestSafetyHelpers.isPathSafeToDelete(homeDir + "/Downloads/old-file.dmg"))

        // Caches should be allowed
        XCTAssertTrue(TestSafetyHelpers.isPathSafeToDelete(homeDir + "/Library/Caches"))
    }
    
    func testAppBundleProtection() {
        // App bundles should never be deleted
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete("/Applications/Xcode.app"))
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete("/Users/test/App.app"))
        XCTAssertFalse(TestSafetyHelpers.isPathSafeToDelete("~/MyApp.app/"))
    }

    // MARK: - Security Scanner Tests

    func testKeyloggerRiskLevels() {
        // Verify all risk levels exist and are distinct
        let risks: [SecurityScanner.KeyloggerRisk] = [.none, .low, .medium, .high]
        XCTAssertEqual(risks.count, 4)
        
        // Verify color mappings
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.none.color, "green")
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.low.color, "yellow")
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.medium.color, "orange")
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.high.color, "red")
    }
    
    func testSecurityRiskOrdering() {
        // Verify all risk levels exist
        let risks: [SecurityScanner.SecurityRisk] = [.unknown, .low, .medium, .high, .critical]
        XCTAssertEqual(risks.count, 5)
        
        // Verify color mappings (proxy for ordering)
        XCTAssertEqual(SecurityScanner.SecurityRisk.unknown.color, "gray")
        XCTAssertEqual(SecurityScanner.SecurityRisk.low.color, "green")
        XCTAssertEqual(SecurityScanner.SecurityRisk.medium.color, "yellow")
        XCTAssertEqual(SecurityScanner.SecurityRisk.high.color, "orange")
        XCTAssertEqual(SecurityScanner.SecurityRisk.critical.color, "red")
    }
    
    func testKnownSafeBundleIDs() {
        // Verify known safe apps are in the whitelist
        let safeBundles = [
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.apple.dt.Xcode"
        ]
        
        for bundle in safeBundles {
            let isSafe = TestSafetyHelpers.isKnownSafeBundleID(bundle)
            XCTAssertTrue(isSafe, "Bundle should be known safe: \(bundle)")
        }
    }
    
    func testSuspiciousKeywords() {
        // Verify suspicious keywords are detected
        let suspiciousNames = [
            "keylogger",
            "screen_capture",
            "password_stealer",
            "remote_backdoor"
        ]
        
        for name in suspiciousNames {
            XCTAssertTrue(
                TestSafetyHelpers.containsSuspiciousKeyword(name),
                "Should detect suspicious keyword: \(name)"
            )
        }
        
        // Verify safe names pass
        let safeNames = ["Safari", "Chrome", "Xcode", "Finder"]
        for name in safeNames {
            XCTAssertFalse(
                TestSafetyHelpers.containsSuspiciousKeyword(name),
                "Should not flag safe name: \(name)"
            )
        }
    }

    // MARK: - AutoKill Whitelist Tests

    func testCriticalProcessesWhitelisted() {
        // Verify critical system processes are in the default whitelist
        let criticalProcesses = [
            "Finder", "WindowServer", "kernel_task", "launchd",
            "loginwindow", "Dock", "SystemUIServer", "mds"
        ]
        
        let manager = AutoKillManager.shared
        
        for process in criticalProcesses {
            XCTAssertTrue(
                manager.isWhitelisted(process),
                "Critical process should be whitelisted: \(process)"
            )
        }
    }
    
    func testSecurityToolsWhitelisted() {
        // Verify third-party security tools are protected
        let securityTools = [
            "Little Snitch", "LuLu", "KnockKnock", "BlockBlock"
        ]
        
        let manager = AutoKillManager.shared
        
        for tool in securityTools {
            XCTAssertTrue(
                manager.isWhitelisted(tool),
                "Security tool should be whitelisted: \(tool)"
            )
        }
    }
    
    func testNonWhitelistedProcess() {
        // Verify random apps are not whitelisted by default
        let manager = AutoKillManager.shared
        XCTAssertFalse(manager.isWhitelisted("RandomApp"))
        XCTAssertFalse(manager.isWhitelisted("Game"))
    }

    // MARK: - Permission Helpers Tests
    // Note: Skipped - requires full app context with UNUserNotificationCenter
}

// MARK: - Test Helpers

/// Helper methods for testing private/internal safety logic
enum TestSafetyHelpers {
    static func isPathSafeToDelete(_ path: String) -> Bool {
        // Replicate the logic from StorageAnalyzer and ComprehensiveOptimizer
        let lowerPath = path.lowercased()

        let protectedPrefixes = [
            "/system", "/bin", "/sbin", "/usr", "/var", "/etc",
            "/applications", "/library", "/network", "/cores",
            "/dev", "/tmp", "/private"
        ]

        for protected in protectedPrefixes {
            if lowerPath.hasPrefix(protected) {
                // Exception for user-writable subdirectories
                if protected == "/var" && lowerPath.contains("/var/folders") {
                    continue
                }
                if protected == "/tmp" && lowerPath.hasPrefix("/var/tmp") {
                    continue
                }
                return false
            }
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path == homeDir ||
           path.hasPrefix(homeDir + "/Documents") ||
           path.hasPrefix(homeDir + "/Desktop") ||
           path.hasPrefix(homeDir + "/Downloads") {
            // Exception: individual files inside Downloads can be cleaned, but not the folder itself
            if path.hasPrefix(homeDir + "/Downloads") && path != homeDir + "/Downloads" {
                return true
            }
            return false
        }

        if lowerPath.hasSuffix(".app") || lowerPath.hasSuffix(".app/") {
            return false
        }

        return true
    }

    static func isKnownSafeBundleID(_ bundleID: String) -> Bool {
        let knownSafeBundleIDs = [
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.apple.dt.Xcode",
            "com.sublimetext.3",
            "com.tinyspeck.slackmacgap",
            "com.hnc.Discord",
            "com.spotify.client",
            "com.dropbox.dropbox",
            "com.microsoft.teams",
            "com.adobe",
            "com.docker.docker",
            "com.macpaw.CleanMyMac",
            "com.littleSnitch",
            "com.objective-see.LuLu",
            "com.opencode",
            "com.paperclip",
        ]
        return knownSafeBundleIDs.contains { bundleID.hasPrefix($0) }
    }

    static func containsSuspiciousKeyword(_ name: String) -> Bool {
        let suspiciousKeywords = [
            "keylog", "logger", "monitor", "track", "spy", "steal",
            "capture", "record", "inject", "hook", "intercept",
            "remote", "backdoor", "trojan", "rat", "keysniff",
            "screencapture", "screen_capture", "mousehook"
        ]
        let lower = name.lowercased()
        return suspiciousKeywords.contains { lower.contains($0) }
    }
}
