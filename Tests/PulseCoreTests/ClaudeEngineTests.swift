//
//  ClaudeEngineTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class ClaudeEngineTests: XCTestCase {

    func testScan_ItemsUseKnownPaths() {
        let engine = ClaudeEngine()
        let plan = engine.scan()
        let knownPaths = [
            "~/.claude/debug",
            "~/.claude/paste-cache",
            "~/.claude/image-cache",
            "~/.claude/shell-snapshots",
            "~/Library/Caches/claude-cli-nodejs",
            "~/.claude/projects",
        ]

        for item in plan.items {
            XCTAssertTrue(knownPaths.contains(item.path), "Unexpected Claude path: \(item.path)")
            XCTAssertEqual(item.profile, .claude)
            XCTAssertEqual(item.category, .logs)
        }
    }

    func testScan_ItemsUseFileAction() {
        let plan = ClaudeEngine().scan()
        for item in plan.items {
            if case .file = item.action {
                // expected
            } else {
                XCTFail("Claude item '\(item.name)' should use .file action")
            }
        }
    }
}
