//
//  AIWorkstationAuditTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class AIWorkstationAuditTests: XCTestCase {

    func testIndexBloatAudit_DoesNotCrash() {
        let issues = IndexBloatAuditScanner().scan(config: PulseConfig())
        XCTAssertGreaterThanOrEqual(issues.count, 0)
    }

    func testAgentDataAudit_DoesNotCrash() {
        let issues = AgentDataAuditScanner().scan()
        XCTAssertGreaterThanOrEqual(issues.count, 0)
    }
}
