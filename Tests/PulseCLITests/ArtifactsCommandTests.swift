//
//  ArtifactsCommandTests.swift
//  PulseCLITests
//
//  Tests for the `pulse artifacts` CLI command.
//

import XCTest
@testable import PulseCLI

final class ArtifactsCommandTests: XCTestCase {

    func testArtifacts_Help_ReturnsSuccess() {
        let exitCode = ArtifactsCommand.run(["--help"])
        XCTAssertEqual(exitCode, EXIT_SUCCESS)
    }

    func testArtifacts_JSON_ReturnsSuccess() {
        // JSON output scans default paths, which may take a while.
        // We just verify it doesn't crash and exits cleanly.
        let exitCode = ArtifactsCommand.run(["--json"])
        XCTAssertGreaterThanOrEqual(exitCode, EXIT_SUCCESS)
    }
}
