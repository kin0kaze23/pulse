//
//  PythonEngineTests.swift
//  PulseCoreTests
//
//  Tests for PythonEngine in PulseCore.
//

import XCTest
@testable import PulseCore

final class PythonEngineTests: XCTestCase {

    func testScan_ItemsHaveCorrectCategory() {
        let engine = PythonEngine()
        let plan = engine.scan()

        for item in plan.items {
            XCTAssertEqual(item.category, .developer)
        }
    }

    func testScan_ItemsHaveFileAction() {
        let engine = PythonEngine()
        let plan = engine.scan()

        for item in plan.items {
            if case .file = item.action {
                // expected
            } else {
                XCTFail("Python item '\(item.name)' should have .file action")
            }
        }
    }

    func testScan_ItemsUseKnownCachePaths() {
        let engine = PythonEngine()
        let plan = engine.scan()

        let knownPaths = [
            "~/Library/Caches/pip",
            "~/Library/Caches/pypoetry",
            "~/Library/Caches/uv",
        ]

        for item in plan.items {
            XCTAssertTrue(knownPaths.contains(item.path), "Unexpected python cache path: \(item.path)")
            XCTAssertEqual(item.profile, .python)
        }
    }

    func testApply_ReturnsEmptyResult() {
        let engine = PythonEngine()
        let result = engine.apply()

        XCTAssertEqual(result.steps.count, 0)
        XCTAssertEqual(result.skipped.count, 0)
        XCTAssertEqual(result.totalFreedMB, 0)
    }
}
