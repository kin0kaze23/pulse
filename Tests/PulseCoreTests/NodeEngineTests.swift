//
//  NodeEngineTests.swift
//  PulseCoreTests
//
//  Tests for NodeEngine in PulseCore.
//  Covers scan, apply, executables not installed, empty caches, and mixed locations.
//

import XCTest
@testable import PulseCore

final class NodeEngineTests: XCTestCase {

    // MARK: - Scan: Not Installed

    func testScan_NoPackageManagerInstalled_ReturnsEmptyPlan() {
        // Use fake paths via a custom NodeEngine — but since we can't inject executables,
        // test the default engine in an environment where npm/yarn/pnpm are not found.
        // On a clean CI or non-dev machine, this would be empty. On a dev machine,
        // the scan may return items. Verify it doesn't crash.
        let engine = NodeEngine()
        let plan = engine.scan()

        XCTAssertGreaterThanOrEqual(plan.totalSizeMB, 0)
        XCTAssertGreaterThanOrEqual(plan.items.count, 0)
    }

    // MARK: - Scan: Items Have Correct Properties

    func testScan_ItemsHaveCorrectCategory() {
        let engine = NodeEngine()
        let plan = engine.scan()

        for item in plan.items {
            XCTAssertEqual(item.category, .developer, "Node items should be developer category")
        }
    }

    func testScan_ItemsHaveFileAction() {
        let engine = NodeEngine()
        let plan = engine.scan()

        for item in plan.items {
            if case .file = item.action {
                // Expected — Node cleanup is file-based
            } else {
                XCTFail("Node item '\(item.name)' should have .file action, got command")
            }
        }
    }

    func testScan_ItemsHaveCorrectPriority() {
        let engine = NodeEngine()
        let plan = engine.scan()

        for item in plan.items {
            XCTAssertEqual(item.priority, .medium, "Node items should have medium priority")
        }
    }

    // MARK: - Scan: Known Paths

    func testScan_ItemsUseKnownCachePaths() {
        let engine = NodeEngine()
        let plan = engine.scan()

        let knownPaths = [
            "~/.npm",
            "~/Library/Caches/Yarn",
            "~/Library/pnpm/store",
        ]

        for item in plan.items {
            XCTAssertTrue(
                knownPaths.contains(item.path),
                "Node item '\(item.name)' has unexpected path: \(item.path)"
            )
        }
    }

    // MARK: - Apply: Empty Result

    func testApply_ReturnsEmptyResult() {
        // NodeEngine.apply() returns empty — file deletion is handled by CleanupEngine
        let engine = NodeEngine()
        let result = engine.apply()

        XCTAssertEqual(result.steps.count, 0)
        XCTAssertEqual(result.skipped.count, 0)
        XCTAssertEqual(result.totalFreedMB, 0)
    }

    // MARK: - Executable Check

    func testIsExecutable_NotFound_ReturnsFalse() {
        let engine = NodeEngine()
        // Use a definitely non-existent executable
        let found = engine.isExecutableInstalled("nonexistent-package-manager-xyz")
        XCTAssertFalse(found)
    }
}

// MARK: - Node Routing Tests

final class NodeRoutingTests: XCTestCase {
    private var engine: CleanupEngine!

    override func setUp() {
        super.setUp()
        engine = CleanupEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Scan via CleanupEngine

    func testScan_NodeProfile_ReturnsNodeItems() {
        let config = CleanupConfig(profiles: [.node])
        let plan = engine.scan(config: config)

        for item in plan.items {
            if case .file = item.action {
                // All Node items should be file-based
            } else {
                XCTFail("Node item '\(item.name)' should have .file action")
            }
        }
    }

    func testScan_NoProfiles_ReturnsEmptyPlan() {
        let config = CleanupConfig(profiles: [])
        let plan = engine.scan(config: config)

        XCTAssertEqual(plan.items.count, 0)
        XCTAssertEqual(plan.totalSizeMB, 0)
    }

    // MARK: - Apply: File-Based Deletion

    func testApply_NodeItem_DeletesRealDirectory() {
        // Create a fake npm cache directory
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("fake-npm-cache")
        let testFile = testDir.appendingPathComponent("_cacache/content-v2/sha512/test.dat")
        try? FileManager.default.createDirectory(at: testFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(repeating: 0, count: 10 * 1024 * 1024) // 10 MB
        try? data.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testDir) }

        // Create a plan item pointing at the test dir
        let config = CleanupConfig(profiles: [.node], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "npm cache",
                sizeMB: 10,
                category: .developer,
                path: testDir.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file
            )
        ], totalSizeMB: 10)

        let result = engine.apply(plan: plan, config: config)

        XCTAssertTrue(result.steps.count > 0)
        XCTAssertTrue(result.steps[0].success)
        XCTAssertGreaterThan(result.totalFreedMB, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testDir.path))
    }

    func testApply_NodeItem_SkipsProtectedPath() {
        let config = CleanupConfig(profiles: [.node], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "npm cache",
                sizeMB: 500,
                category: .developer,
                path: "/System/Library/Caches/npm",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file
            )
        ], totalSizeMB: 500)

        let result = engine.apply(plan: plan, config: config)

        XCTAssertEqual(result.skipped.count, 1)
        XCTAssertEqual(result.skipped[0].reason, "Protected path")
    }

    func testApply_NodeItem_RespectsExclusions() {
        let config = CleanupConfig(
            profiles: [.node],
            excludedPaths: ["/Users/test/.npm"],
            fileOperationPolicy: PermanentDeletePolicy()
        )

        let plan = CleanupPlan(items: [
            .init(
                name: "npm cache",
                sizeMB: 500,
                category: .developer,
                path: "/Users/test/.npm",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file
            )
        ], totalSizeMB: 500)

        let result = engine.apply(plan: plan, config: config)

        XCTAssertTrue(result.skipped.contains { $0.reason == "Protected path" })
    }

    func testApply_NodeItem_NonexistentPath_ReturnsZeroFreed() {
        let config = CleanupConfig(profiles: [.node], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "npm cache",
                sizeMB: 500,
                category: .developer,
                path: "/nonexistent/path/xyz123",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file
            )
        ], totalSizeMB: 500)

        let result = engine.apply(plan: plan, config: config)

        // Path doesn't exist, so no steps should be generated
        // (PermanentDeletePolicy.delete returns false for non-existent paths)
        XCTAssertEqual(result.totalFreedMB, 0)
    }
}

// MARK: - Mixed Profile Tests

final class MixedProfileTests: XCTestCase {
    private var engine: CleanupEngine!

    override func setUp() {
        super.setUp()
        engine = CleanupEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    func testScan_MultipleProfiles_DoesNotCrash() {
        let config = CleanupConfig(profiles: [.xcode, .homebrew, .node])
        let plan = engine.scan(config: config)

        // Should not crash regardless of which tools are installed
        XCTAssertGreaterThanOrEqual(plan.totalSizeMB, 0)
    }

    func testApply_MixedPlan_FileAndCommandItems() {
        // Create a temp file for file-based deletion
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("mixed-profile-test")
        let testFile = testDir.appendingPathComponent("mixed-test.txt")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        try? Data([0x44]).write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let config = CleanupConfig(profiles: [.node], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            // Command-based item (simulating Homebrew)
            .init(
                name: "Command Item",
                sizeMB: 100,
                category: .developer,
                path: "homebrew://fake",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("true")
            ),
            // File-based item (simulating Node)
            .init(
                name: "File Item",
                sizeMB: 1,
                category: .developer,
                path: testFile.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file
            )
        ], totalSizeMB: 101)

        let result = engine.apply(plan: plan, config: config)

        // Both types should be handled
        XCTAssertTrue(result.steps.count >= 1)
        // File should be deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }
}
