//
//  RustEngineTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class RustEngineTests: XCTestCase {

    func testScan_ItemsUseKnownPaths() {
        let plan = RustEngine().scan()
        let knownPaths = ["~/.cargo/registry", "~/.cargo/git"]
        for item in plan.items {
            XCTAssertTrue(knownPaths.contains(item.path))
            XCTAssertEqual(item.profile, .rust)
            XCTAssertEqual(item.category, .developer)
        }
    }

    func testScan_ItemsUseFileAction() {
        let plan = RustEngine().scan()
        for item in plan.items {
            if case .file = item.action {
                // expected
            } else {
                XCTFail("Rust item '\(item.name)' should use .file action")
            }
        }
    }
}
