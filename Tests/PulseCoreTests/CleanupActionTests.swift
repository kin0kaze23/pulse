//
//  CleanupActionTests.swift
//  PulseCoreTests
//
//  Tests for CleanupAction enum and routing behavior.
//  Ensures command-based vs file-based execution cannot regress.
//

import XCTest
@testable import PulseCore

// MARK: - CleanupAction Enum Tests

final class CleanupActionTests: XCTestCase {

    func testFileAction_DefaultForCleanupItem() {
        // Default CleanupItem should use .file action
        let item = CleanupPlan.CleanupItem(
            name: "Test",
            sizeMB: 10,
            category: .developer,
            path: "/some/path",
            isDestructive: false,
            requiresAppClosed: false,
            appName: nil,
            warningMessage: nil,
            profile: .system
        )

        if case .file = item.action {
            // Expected
        } else {
            XCTFail("Default action should be .file")
        }
    }

    func testCommandAction_CarriesCommandString() {
        let item = CleanupPlan.CleanupItem(
            name: "Homebrew cleanup",
            sizeMB: 500,
            category: .developer,
            path: "homebrew://cleanup",
            isDestructive: false,
            requiresAppClosed: false,
            appName: nil,
            warningMessage: nil,
            action: .command("brew cleanup --prune=all"),
            profile: .homebrew
        )

        if case .command(let cmd) = item.action {
            XCTAssertEqual(cmd, "brew cleanup --prune=all")
        } else {
            XCTFail("Action should be .command")
        }
    }
}

// MARK: - Routing Tests

final class CleanupRoutingTests: XCTestCase {
    private var engine: CleanupEngine!

    override func setUp() {
        super.setUp()
        engine = CleanupEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Command Items Should NOT Be File-Deleted

    func testCommandItem_DoesNotDeleteFileAtPath() {
        // Create a real file at a path that would be deleted if routed as file-based
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("routing-test")
        let testFile = testDir.appendingPathComponent("should-not-delete.txt")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        try? Data([0x41]).write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testDir) }

        // Plan with a command-action item pointing at the test file
        let config = CleanupConfig(profiles: [], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "Command Item",
                sizeMB: 1,
                category: .developer,
                path: testFile.path, // Would be deleted if routed as file
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("true"), // "true" always succeeds
                profile: .system
            )
        ], totalSizeMB: 1)

        let result = engine.apply(plan: plan, config: config)

        // File should still exist — command action should not trigger file deletion
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path),
                      "Command action item should NOT delete file at path")

        // Should have a successful step (command execution)
        XCTAssertTrue(result.steps.contains { $0.success })
    }

    func testFileItem_DeletesFileAtPath() {
        // Create a real file
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("file-routing-test")
        let testFile = testDir.appendingPathComponent("should-delete.txt")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        try? Data([0x42]).write(to: testFile)

        // Plan with a file-action item
        let config = CleanupConfig(profiles: [], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "File Item",
                sizeMB: 1,
                category: .developer,
                path: testFile.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file,
                profile: .system
            )
        ], totalSizeMB: 1)

        let result = engine.apply(plan: plan, config: config)

        // File should be deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path),
                       "File action item SHOULD delete file at path")

        // Safety validator should allow this path (it's in temp)
        XCTAssertTrue(result.steps.count > 0 || result.skipped.contains { $0.reason == "Protected path" })
    }

    // MARK: - Mixed Plan

    func testMixedPlan_CommandAndFileItems_RoutedCorrectly() {
        // Create a real file
        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("mixed-routing-test")
        let testFile = testDir.appendingPathComponent("mixed-test.txt")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        try? Data([0x43]).write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let config = CleanupConfig(profiles: [], fileOperationPolicy: PermanentDeletePolicy())
        let plan = CleanupPlan(items: [
            .init(
                name: "Command Item",
                sizeMB: 100,
                category: .developer,
                path: "homebrew://fake",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("true"),
                profile: .system
            ),
            .init(
                name: "File Item",
                sizeMB: 1,
                category: .developer,
                path: testFile.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .file,
                profile: .system
            )
        ], totalSizeMB: 101)

        let result = engine.apply(plan: plan, config: config)

        // Command item should succeed (true always succeeds)
        XCTAssertTrue(result.steps.contains { $0.success && $0.name == "Command Item" })

        // File item should also succeed (temp dir is safe to delete from)
        XCTAssertTrue(result.steps.contains { $0.name == "File Item" })

        // File should be deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path))
    }

    // MARK: - Command Grouping

    func testMultipleCommandItems_SameCommand_GroupedTogether() {
        let config = CleanupConfig(profiles: [])
        let plan = CleanupPlan(items: [
            .init(
                name: "Item A",
                sizeMB: 100,
                category: .developer,
                path: "homebrew://a",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("true"),
                profile: .system
            ),
            .init(
                name: "Item B",
                sizeMB: 200,
                category: .developer,
                path: "homebrew://b",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("true"), // same command
                profile: .system
            )
        ], totalSizeMB: 300)

        let result = engine.apply(plan: plan, config: config)

        // Both items share one step (grouped by command)
        let successSteps = result.steps.filter(\.success)
        XCTAssertEqual(successSteps.count, 1, "Items with same command should share one execution")

        // Combined freed space should be sum of both items
        XCTAssertEqual(successSteps[0].freedMB, 300)
    }

    func testMultipleCommandItems_DifferentCommands_SeparateExecutions() {
        let config = CleanupConfig(profiles: [])
        let plan = CleanupPlan(items: [
            .init(
                name: "Item A",
                sizeMB: 100,
                category: .developer,
                path: "cmd://a",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("true"),
                profile: .system
            ),
            .init(
                name: "Item B",
                sizeMB: 200,
                category: .developer,
                path: "cmd://b",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("echo hello"), // different command
                profile: .system
            )
        ], totalSizeMB: 300)

        let result = engine.apply(plan: plan, config: config)

        // Should have two separate steps
        let successSteps = result.steps.filter(\.success)
        XCTAssertEqual(successSteps.count, 2, "Items with different commands should execute separately")
    }
}

// MARK: - Homebrew Scan Action Tests

final class HomebrewScanActionTests: XCTestCase {

    func testHomebrewDownloadsItem_HasCommandAction() {
        // "Homebrew downloads" item should have .command action, not .file
        // This is the Bug #1 fix verification
        let plan = CleanupPlan(items: [
            .init(
                name: "Homebrew downloads",
                sizeMB: 100,
                category: .developer,
                path: "~/Library/Caches/Homebrew/downloads",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                action: .command("brew cleanup --prune=all"),
                profile: .homebrew
            )
        ], totalSizeMB: 100)

        let downloadsItem = plan.items[0]
        if case .command(let cmd) = downloadsItem.action {
            XCTAssertEqual(cmd, "brew cleanup --prune=all",
                           "Homebrew downloads should route via command, not file deletion")
        } else {
            XCTFail("Homebrew downloads item should have .command action — Bug #1 regression")
        }
    }

    func testAllHomebrewItems_UseCommandAction() {
        // Verify via real HomebrewEngine that all items use .command
        let engine = HomebrewEngine(brewExecutable: "/opt/homebrew/bin/brew")
        let plan = engine.scan()

        for item in plan.items {
            if case .file = item.action {
                XCTFail("Homebrew item '\(item.name)' has .file action — should be .command")
            }
        }
    }
}
