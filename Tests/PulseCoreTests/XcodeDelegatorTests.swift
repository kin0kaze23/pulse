//
//  XcodeDelegatorTests.swift
//  PulseCoreTests
//
//  Tests for the XcodeDelegator adapter between Pulse app and PulseCore.
//

import XCTest
@testable import PulseCore

final class XcodeDelegatorIntegrationTests: XCTestCase {
    private var engine: CleanupEngine!

    override func setUp() {
        super.setUp()
        engine = CleanupEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Scan Tests

    func testScanXcodeConfig_ReturnsNonNegativePlan() {
        let config = CleanupConfig(profiles: [.xcode])
        let plan = engine.scan(config: config)

        // Should not crash regardless of whether Xcode paths exist
        XCTAssertGreaterThanOrEqual(plan.totalSizeMB, 0)
        XCTAssertGreaterThanOrEqual(plan.items.count, 0)
    }

    func testScanEmptyProfiles_ReturnsEmptyPlan() {
        let config = CleanupConfig(profiles: [])
        let plan = engine.scan(config: config)

        XCTAssertEqual(plan.items.count, 0)
        XCTAssertEqual(plan.totalSizeMB, 0)
    }

    func testScanXcodeConfig_ItemsHaveCorrectCategory() {
        let config = CleanupConfig(profiles: [.xcode])
        let plan = engine.scan(config: config)

        for item in plan.items {
            XCTAssertEqual(item.category, .developer, "Xcode items should be developer category")
        }
    }

    // MARK: - Apply Tests (Permanent Delete for deterministic assertions)

    func testApplySkipsNonexistentPath() {
        let config = CleanupConfig(profiles: [.xcode], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "Fake Xcode Cache",
                sizeMB: 10,
                category: .developer,
                path: "/nonexistent/xcode/path",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil
            )
        ], totalSizeMB: 10)

        let result = engine.apply(plan: plan, config: config)
        XCTAssertEqual(result.totalFreedMB, 0)
    }

    func testApplyDeletesTestDirectory() {
        let testDir = createTestDirectory(named: "xcode-delegator-test", sizeMB: 5)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let config = CleanupConfig(profiles: [.xcode], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "Test Xcode Cleanup",
                sizeMB: 5,
                category: .developer,
                path: testDir.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil
            )
        ], totalSizeMB: 5)

        let result = engine.apply(plan: plan, config: config)

        XCTAssertTrue(result.steps.count > 0)
        XCTAssertTrue(result.steps[0].success)
        XCTAssertGreaterThan(result.totalFreedMB, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.path))
    }

    // MARK: - Safety Tests

    func testApplySkipsProtectedPath() {
        let config = CleanupConfig(profiles: [.xcode], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "System Path",
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

        XCTAssertEqual(result.skipped.count, 1)
        XCTAssertEqual(result.skipped[0].reason, "Protected path")
    }

    func testApplyRespectsExcludedPaths() {
        let config = CleanupConfig(
            profiles: [.xcode],
            excludedPaths: ["/Users/test/Library/Developer/Xcode/DerivedData"],
            fileOperationPolicy: PermanentDeletePolicy()
        )

        let plan = CleanupPlan(items: [
            .init(
                name: "Excluded Path",
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
        XCTAssertTrue(result.skipped.contains { $0.reason == "Protected path" })
    }

    // MARK: - Deletion Strategy Tests

    func testTrashFirstPolicy_MovesToTrash() {
        let testDir = createTestDirectory(named: "trash-test", sizeMB: 1)
        let policy = TrashFirstPolicy()

        let success = try? policy.delete(path: testDir.path)
        XCTAssertTrue(success == true)

        // Original path should be gone (moved to Trash)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.path))
    }

    func testTrashFirstPolicy_RecreatesCacheDirectory() {
        // DerivedData is a cache path — should be recreated after trash
        let testDir = createTestDirectory(named: "DerivedData", sizeMB: 1)
        let policy = TrashFirstPolicy()

        let success = try? policy.delete(path: testDir.path)
        XCTAssertTrue(success == true)

        // Cache directories should be recreated after deletion
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDir.path))
    }

    func testPermanentDeletePolicy_RemovesPermanently() {
        let testDir = createTestDirectory(named: "permanent-test", sizeMB: 1)
        let policy = PermanentDeletePolicy()

        let success = try? policy.delete(path: testDir.path)
        XCTAssertTrue(success == true)

        // Should be permanently deleted — no recreation
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.path))
    }

    func testDefaultConfig_UsesTrashStrategy() {
        let config = CleanupConfig()
        XCTAssertEqual(config.deletionStrategy, .trash)
        XCTAssertTrue(config.fileOperationPolicy is TrashFirstPolicy)
    }

    // MARK: - Helpers

    private func createTestDirectory(named name: String, sizeMB: Int) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let filePath = dir.appendingPathComponent("testfile.dat")
        let data = Data(repeating: 0, count: sizeMB * 1024 * 1024)
        try? data.write(to: filePath)

        return dir
    }
}
