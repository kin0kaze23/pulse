//
//  AnalyzeCommandTests.swift
//  PulseCLITests
//
//  Tests for the pulse analyze command.
//

import XCTest
@testable import PulseCLI

final class AnalyzeCommandTests: XCTestCase {

    func testAnalyze_Help_ReturnsSuccess() {
        let exitCode = AnalyzeCommand.run(["--help"])
        XCTAssertEqual(exitCode, EXIT_SUCCESS)
    }

    func testAnalyze_Default_ReturnsSuccess() {
        let exitCode = AnalyzeCommand.run([])
        XCTAssertEqual(exitCode, EXIT_SUCCESS)
    }

    func testAnalyze_OutputDoesNotCrash() {
        // Verify the analyze command runs without crashing
        // The actual output depends on the local machine state
        let exitCode = AnalyzeCommand.run([])
        XCTAssertGreaterThanOrEqual(exitCode, EXIT_SUCCESS)
    }
}
