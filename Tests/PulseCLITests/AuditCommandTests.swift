//
//  AuditCommandTests.swift
//  PulseCLITests
//

import XCTest
@testable import PulseCLI

final class AuditCommandTests: XCTestCase {

    func testAudit_Default_ReturnsSuccess() {
        XCTAssertEqual(AuditCommand.run([]), EXIT_SUCCESS)
    }

    func testAudit_IndexBloat_ReturnsSuccess() {
        XCTAssertEqual(AuditCommand.run(["index-bloat"]), EXIT_SUCCESS)
    }

    func testAudit_AgentData_ReturnsSuccess() {
        XCTAssertEqual(AuditCommand.run(["agent-data"]), EXIT_SUCCESS)
    }

    func testAudit_Models_ReturnsSuccess() {
        XCTAssertEqual(AuditCommand.run(["models"]), EXIT_SUCCESS)
    }

    func testAudit_Help_ReturnsSuccess() {
        XCTAssertEqual(AuditCommand.run(["--help"]), EXIT_SUCCESS)
    }
}
