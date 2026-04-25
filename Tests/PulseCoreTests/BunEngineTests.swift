//
//  BunEngineTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class BunEngineTests: XCTestCase {

    func testScan_ItemsUseKnownPaths() {
        let plan = BunEngine().scan()
        for item in plan.items {
            XCTAssertEqual(item.path, "~/.bun/install/cache")
            XCTAssertEqual(item.profile, .bun)
            XCTAssertEqual(item.category, .developer)
        }
    }

    func testScan_ItemsUseFileAction() {
        let plan = BunEngine().scan()
        for item in plan.items {
            if case .file = item.action {
                // expected
            } else {
                XCTFail("Bun item '\(item.name)' should use .file action")
            }
        }
    }
}
