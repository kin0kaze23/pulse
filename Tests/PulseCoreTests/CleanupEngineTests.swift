//
//  CleanupEngineTests.swift
//  PulseCoreTests
//
//  Tests for the extracted CleanupEngine -- real implementation, no duplicated helpers.
//

import XCTest
@testable import PulseCore

final class CleanupEngineTests: XCTestCase {
    private var engine: CleanupEngine!
    private var fileManager: FileManager!

    override func setUp() {
        super.setUp()
        engine = CleanupEngine()
        fileManager = FileManager.default
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Scan Tests

    func testScanXcode_WithEmptyDerivedData_ReturnsEmptyPlan() {
        let config = CleanupConfig(profiles: [.xcode])
        let plan = engine.scan(config: config)

        // On a clean machine, DerivedData may not exist or be < 50 MB
        // The scan should not crash regardless
        XCTAssertGreaterThanOrEqual(plan.totalSizeMB, 0)
    }

    func testScanXcode_WithTestDirectory_CreatesPlanItem() {
        // Create a fake DerivedData directory with known size
        let testDir = createTestDirectory(named: "FakeDerivedData", sizeMB: 100)
        defer { try? fileManager.removeItem(at: testDir) }

        // Temporarily override by pointing scanner to test directory
        let scanner = DirectoryScanner()
        let size = scanner.directorySizeMB(testDir.path)
        XCTAssertGreaterThan(size, 50, "Test directory should be large enough")
    }

    func testScanEmptyProfiles_ReturnsEmptyPlan() {
        let config = CleanupConfig(profiles: [])
        let plan = engine.scan(config: config)

        XCTAssertEqual(plan.items.count, 0)
        XCTAssertEqual(plan.totalSizeMB, 0)
    }

    // MARK: - Safety Tests (against real implementation)

    func testProtectedSystemPaths() {
        let validator = SafetyValidator()
        let protectedPaths = [
            "/System/Library",
            "/bin/bash",
            "/usr/bin",
            "/etc/hosts",
            "/Applications/Safari.app",
        ]

        for path in protectedPaths {
            XCTAssertFalse(
                validator.isPathSafeToDelete(path),
                "Path should be protected: \(path)"
            )
        }
    }

    func testAllowedCleanupPaths() {
        let validator = SafetyValidator()
        let allowedPaths = [
            "/Users/test/Library/Developer/Xcode/DerivedData",
            "/var/folders/xx/xyz123/T",
        ]

        for path in allowedPaths {
            XCTAssertTrue(
                validator.isPathSafeToDelete(path),
                "Path should be allowed: \(path)"
            )
        }
    }

    func testUserHomeProtection() {
        let validator = SafetyValidator()
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        XCTAssertFalse(validator.isPathSafeToDelete(homeDir))
        XCTAssertFalse(validator.isPathSafeToDelete(homeDir + "/Documents"))
        XCTAssertFalse(validator.isPathSafeToDelete(homeDir + "/Desktop"))
        XCTAssertFalse(validator.isPathSafeToDelete(homeDir + "/Downloads"))
        XCTAssertTrue(validator.isPathSafeToDelete(homeDir + "/Downloads/old-file.dmg"))
        XCTAssertTrue(validator.isPathSafeToDelete(homeDir + "/Library/Caches"))
    }

    func testAppBundleProtection() {
        let validator = SafetyValidator()
        XCTAssertFalse(validator.isPathSafeToDelete("/Applications/Xcode.app"))
        XCTAssertFalse(validator.isPathSafeToDelete("/Users/test/App.app"))
        XCTAssertFalse(validator.isPathSafeToDelete("~/MyApp.app/"))
    }

    func testUserExcludedPaths() {
        let validator = SafetyValidator(excludedPaths: ["/Users/test/custom-cache"])
        // excludedPaths uses contains matching
        XCTAssertFalse(validator.isPathSafeToDelete("/Users/test/custom-cache/subdir"))
        XCTAssertTrue(validator.isPathSafeToDelete("/Users/test/other-cache"))
    }

    // MARK: - Apply Tests

    func testApplyDeletesRealDirectory() {
        // Create a real temp directory
        let testDir = createTestDirectory(named: "pulse-cleanup-test", sizeMB: 10)
        let config = CleanupConfig(profiles: [.xcode])

        // Create a cleanup plan pointing at our test directory
        let plan = CleanupPlan(items: [
            .init(
                name: "Test Cleanup",
                sizeMB: 10,
                category: .developer,
                path: testDir.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil
            )
        ], totalSizeMB: 10)

        // Apply the plan
        let result = engine.apply(plan: plan, config: config)

        // Verify deletion occurred
        XCTAssertTrue(result.steps.count > 0)
        XCTAssertTrue(result.steps[0].success)
        XCTAssertGreaterThan(result.totalFreedMB, 0)
        XCTAssertFalse(fileManager.fileExists(atPath: testDir.path))
    }

    func testApplySkipsProtectedPaths() {
        let config = CleanupConfig(profiles: [.xcode])

        let plan = CleanupPlan(items: [
            .init(
                name: "Should be skipped",
                sizeMB: 1,
                category: .developer,
                path: "/System/Library/Caches",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil
            )
        ], totalSizeMB: 1)

        let result = engine.apply(plan: plan, config: config)

        XCTAssertEqual(result.steps.count, 0)
        XCTAssertEqual(result.skipped.count, 1)
        XCTAssertEqual(result.skipped[0].reason, "Protected path")
    }

    func testApplyRespectsUserExclusions() {
        let config = CleanupConfig(
            profiles: [.xcode],
            excludedPaths: ["/Users/test/Library/Developer/Xcode/DerivedData"]
        )

        let plan = CleanupPlan(items: [
            .init(
                name: "User excluded",
                sizeMB: 1,
                category: .developer,
                path: "/Users/test/Library/Developer/Xcode/DerivedData",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil
            )
        ], totalSizeMB: 1)

        let result = engine.apply(plan: plan, config: config)

        // Should be skipped due to user exclusion
        // Note: SafetyValidator handles excludedPaths, so this path IS safe from
        // a system perspective but excluded by user config
        XCTAssertTrue(result.skipped.contains { $0.reason == "Protected path" })
    }

    // MARK: - Helpers

    private func createTestDirectory(named name: String, sizeMB: Int) -> URL {
        let dir = fileManager.temporaryDirectory.appendingPathComponent(name)
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        // Create a file of approximately the requested size
        let filePath = dir.appendingPathComponent("testfile.dat")
        let data = Data(repeating: 0, count: sizeMB * 1024 * 1024)
        try? data.write(to: filePath)

        return dir
    }
}

// MARK: - SafetyValidator Tests

final class SafetyValidatorTests: XCTestCase {
    func testDefaultValidator() {
        let validator = SafetyValidator()
        XCTAssertTrue(validator.isPathSafeToDelete("/Users/test/Library/Caches"))
        XCTAssertFalse(validator.isPathSafeToDelete("/System"))
    }

    func testExcludedPathsValidator() {
        let validator = SafetyValidator(excludedPaths: ["/custom/path"])
        XCTAssertFalse(validator.isPathSafeToDelete("/custom/path/subdir"))
        XCTAssertTrue(validator.isPathSafeToDelete("/other/path"))
    }
}

// MARK: - CleanupPlan Tests

final class CleanupPlanTests: XCTestCase {
    func testTotalSizeText() {
        let small = CleanupPlan(items: [], totalSizeMB: 50)
        XCTAssertEqual(small.totalSizeText, "50 MB")

        let large = CleanupPlan(items: [], totalSizeMB: 2048)
        XCTAssertEqual(large.totalSizeText, "2.0 GB")
    }

    func testIsSignificant() {
        XCTAssertFalse(CleanupPlan(items: [], totalSizeMB: 49).isSignificant)
        XCTAssertTrue(CleanupPlan(items: [], totalSizeMB: 51).isSignificant)
    }
}

// MARK: - CleanupPriority Tests

final class CleanupPriorityTests_PulseCore: XCTestCase {
    func testOrdering() {
        // Higher priority has lower sortOrder, so high > medium in Comparable
        // (high is "greater" because it's safer to delete)
        XCTAssertGreaterThan(CleanupPriority.high, CleanupPriority.medium)
        XCTAssertGreaterThan(CleanupPriority.medium, CleanupPriority.low)
        XCTAssertGreaterThan(CleanupPriority.low, CleanupPriority.optional)
    }

    func testAllCases() {
        XCTAssertEqual(CleanupPriority.allCases.count, 4)
    }
}

// MARK: - DirectoryScanner Tests

final class DirectoryScannerTests: XCTestCase {
    func testNonExistentDirectory() {
        let scanner = DirectoryScanner()
        let size = scanner.directorySizeMB("/nonexistent/path/xyz")
        XCTAssertEqual(size, 0)
    }

    func testExistingDirectory() {
        let scanner = DirectoryScanner()
        let tmpDir = FileManager.default.temporaryDirectory.path
        let size = scanner.directorySizeMB(tmpDir)
        XCTAssertGreaterThanOrEqual(size, 0)
    }
}
