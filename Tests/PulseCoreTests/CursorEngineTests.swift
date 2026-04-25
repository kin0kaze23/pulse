//
//  CursorEngineTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class CursorEngineTests: XCTestCase {

    func testScan_ItemsUseKnownPaths() {
        let engine = CursorEngine()
        let plan = engine.scan()
        let knownPaths = [
            "~/Library/Application Support/Cursor/Cache",
            "~/Library/Application Support/Cursor/CachedData",
            "~/Library/Application Support/Cursor/Code Cache",
            "~/Library/Application Support/Cursor/logs",
            "~/Library/Application Support/Cursor/CachedExtensionVSIXs",
            "~/Library/Caches/com.todesktop.runtime.Cursor",
            "~/Library/Application Support/Cursor/User/workspaceStorage",
        ]

        for item in plan.items {
            XCTAssertTrue(knownPaths.contains(item.path), "Unexpected Cursor path: \(item.path)")
            XCTAssertEqual(item.profile, .cursor)
            XCTAssertEqual(item.category, .developer)
        }
    }

    func testScan_ItemsRequireCursorClosed() {
        let plan = CursorEngine().scan()
        for item in plan.items {
            XCTAssertTrue(item.requiresAppClosed)
            XCTAssertEqual(item.appName, "Cursor")
        }
    }
}
