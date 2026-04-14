import XCTest
@testable import Pulse

/// Integration tests for safety-critical features.
/// Tests the ACTUAL implementation in ComprehensiveOptimizer and StorageAnalyzer,
/// not duplicated test helpers.
final class SafetyFeaturesTests: XCTestCase {

    // MARK: - Path Safety Tests (ComprehensiveOptimizer)

    func testProtectedSystemPaths_ComprehensiveOptimizer() {
        let optimizer = ComprehensiveOptimizer.shared
        let protectedPaths = [
            "/System/Library",
            "/bin/bash",
            "/usr/bin",
            "/etc/hosts",
            "/Applications/Safari.app",
        ]

        for path in protectedPaths {
            XCTAssertFalse(
                optimizer.isPathSafeToDelete(path),
                "[ComprehensiveOptimizer] Path should be protected: \(path)"
            )
        }
    }

    func testProtectedSystemPaths_StorageAnalyzer() {
        let analyzer = StorageAnalyzer.shared
        let protectedPaths = [
            "/System/Library",
            "/bin/bash",
            "/usr/bin",
            "/var/log",
            "/etc/hosts",
            "/Library/LaunchDaemons",
            "/Applications/Safari.app",
        ]

        for path in protectedPaths {
            XCTAssertFalse(
                analyzer.isPathSafeToDelete(path),
                "[StorageAnalyzer] Path should be protected: \(path)"
            )
        }
    }

    func testAllowedCleanupPaths_ComprehensiveOptimizer() {
        let optimizer = ComprehensiveOptimizer.shared
        let allowedPaths = [
            "/Users/test/Library/Developer/Xcode/DerivedData",
            "/var/folders/xx/xyz123/T",
        ]

        for path in allowedPaths {
            XCTAssertTrue(
                optimizer.isPathSafeToDelete(path),
                "[ComprehensiveOptimizer] Path should be allowed: \(path)"
            )
        }
    }

    func testAllowedCleanupPaths_StorageAnalyzer() {
        let analyzer = StorageAnalyzer.shared
        let allowedPaths = [
            "/Users/test/Library/Caches/com.apple.Safari",
            "/Users/test/Library/Developer/Xcode/DerivedData",
            "/Users/test/Library/Caches/Homebrew",
            "/var/folders/xx/xyz123/T",
        ]

        for path in allowedPaths {
            XCTAssertTrue(
                analyzer.isPathSafeToDelete(path),
                "[StorageAnalyzer] Path should be allowed: \(path)"
            )
        }
    }

    func testUserHomeProtection_ComprehensiveOptimizer() {
        let optimizer = ComprehensiveOptimizer.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        XCTAssertFalse(optimizer.isPathSafeToDelete(homeDir))
        XCTAssertFalse(optimizer.isPathSafeToDelete(homeDir + "/Documents"))
        XCTAssertFalse(optimizer.isPathSafeToDelete(homeDir + "/Desktop"))
        XCTAssertFalse(optimizer.isPathSafeToDelete(homeDir + "/Downloads"))
        XCTAssertTrue(optimizer.isPathSafeToDelete(homeDir + "/Downloads/old-file.dmg"))
        XCTAssertTrue(optimizer.isPathSafeToDelete(homeDir + "/Library/Caches"))
    }

    func testUserHomeProtection_StorageAnalyzer() {
        let analyzer = StorageAnalyzer.shared
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        XCTAssertFalse(analyzer.isPathSafeToDelete(homeDir))
        XCTAssertFalse(analyzer.isPathSafeToDelete(homeDir + "/Documents"))
        XCTAssertFalse(analyzer.isPathSafeToDelete(homeDir + "/Desktop"))
        XCTAssertFalse(analyzer.isPathSafeToDelete(homeDir + "/Downloads"))
        XCTAssertTrue(analyzer.isPathSafeToDelete(homeDir + "/Downloads/old-file.dmg"))
        XCTAssertTrue(analyzer.isPathSafeToDelete(homeDir + "/Library/Caches"))
    }

    func testAppBundleProtection_ComprehensiveOptimizer() {
        let optimizer = ComprehensiveOptimizer.shared
        XCTAssertFalse(optimizer.isPathSafeToDelete("/Applications/Xcode.app"))
        XCTAssertFalse(optimizer.isPathSafeToDelete("/Users/test/App.app"))
        XCTAssertFalse(optimizer.isPathSafeToDelete("~/MyApp.app/"))
    }

    func testAppBundleProtection_StorageAnalyzer() {
        let analyzer = StorageAnalyzer.shared
        XCTAssertFalse(analyzer.isPathSafeToDelete("/Applications/Xcode.app"))
        XCTAssertFalse(analyzer.isPathSafeToDelete("/Users/test/App.app"))
        XCTAssertFalse(analyzer.isPathSafeToDelete("~/MyApp.app/"))
    }

    // MARK: - Integration Test: Temp Directory Scan

    func testTempDirectoryScanRespectsProtectedPaths() {
        // Create a temp directory with known structure
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-safety-test-\(UUID().uuidString)")

        // Create allowed subdirectories
        let cacheDir = tempDir.appendingPathComponent("caches")
        let derivedDataDir = tempDir.appendingPathComponent("DerivedData")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: derivedDataDir, withIntermediateDirectories: true)

        // Create test files
        let allowedFile = cacheDir.appendingPathComponent("test-cache.dat")
        FileManager.default.createFile(atPath: allowedFile.path, contents: Data(repeating: 0, count: 100))

        // Run scanForCleanup and verify no protected paths appear in the plan
        let optimizer = ComprehensiveOptimizer.shared
        optimizer.scanForCleanup()

        // Wait briefly for async scan to populate
        let expectation = XCTestExpectation(description: "scan completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)

        // Verify the scan ran without crashing (proves safety checks don't break)
        // The actual CleanupPlan is stored in optimizer.currentPlan
        // Check that no system paths appear in any cleanup items
        if let plan = optimizer.currentPlan {
            for item in plan.items {
                XCTAssertFalse(
                    item.path.hasPrefix("/System") ||
                    item.path.hasPrefix("/usr") ||
                    item.path.hasPrefix("/bin") ||
                    item.path.hasPrefix("/sbin"),
                    "Cleanup plan should not include system paths: \(item.path)"
                )
            }
        }

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Security Scanner Tests

    func testKeyloggerRiskLevels() {
        let risks: [SecurityScanner.KeyloggerRisk] = [.none, .low, .medium, .high]
        XCTAssertEqual(risks.count, 4)

        XCTAssertEqual(SecurityScanner.KeyloggerRisk.none.color, "green")
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.low.color, "yellow")
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.medium.color, "orange")
        XCTAssertEqual(SecurityScanner.KeyloggerRisk.high.color, "red")
    }

    func testSecurityRiskOrdering() {
        let risks: [SecurityScanner.SecurityRisk] = [.unknown, .low, .medium, .high, .critical]
        XCTAssertEqual(risks.count, 5)

        XCTAssertEqual(SecurityScanner.SecurityRisk.unknown.color, "gray")
        XCTAssertEqual(SecurityScanner.SecurityRisk.low.color, "green")
        XCTAssertEqual(SecurityScanner.SecurityRisk.medium.color, "yellow")
        XCTAssertEqual(SecurityScanner.SecurityRisk.high.color, "orange")
        XCTAssertEqual(SecurityScanner.SecurityRisk.critical.color, "red")
    }

    func testKnownSafeBundleIDs() {
        let scanner = SecurityScanner.shared
        let safeBundles = [
            "com.microsoft.VSCode",
            "com.jetbrains.intellij",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.apple.dt.Xcode",
        ]

        for bundle in safeBundles {
            XCTAssertTrue(
                scanner.isKnownSafeBundleID(bundle),
                "Bundle should be known safe: \(bundle)"
            )
        }
    }

    func testSuspiciousKeywords() {
        let scanner = SecurityScanner.shared
        let suspiciousNames = [
            "keylogger",
            "screen_capture",
            "password_stealer",
            "remote_backdoor",
        ]

        for name in suspiciousNames {
            XCTAssertTrue(
                scanner.containsSuspiciousKeyword(name),
                "Should detect suspicious keyword: \(name)"
            )
        }

        let safeNames = ["Safari", "Chrome", "Xcode", "Finder"]
        for name in safeNames {
            XCTAssertFalse(
                scanner.containsSuspiciousKeyword(name),
                "Should not flag safe name: \(name)"
            )
        }
    }

    // MARK: - AutoKill Whitelist Tests

    func testCriticalProcessesWhitelisted() {
        let criticalProcesses = [
            "Finder", "WindowServer", "kernel_task", "launchd",
            "loginwindow", "Dock", "SystemUIServer", "mds",
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
        let securityTools = [
            "Little Snitch", "LuLu", "KnockKnock", "BlockBlock",
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
        let manager = AutoKillManager.shared
        XCTAssertFalse(manager.isWhitelisted("RandomApp"))
        XCTAssertFalse(manager.isWhitelisted("Game"))
    }

    // MARK: - Permission Helpers Tests
    // Note: Skipped - requires full app context with UNUserNotificationCenter
}
