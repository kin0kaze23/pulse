import XCTest
@testable import Pulse

final class SecurityScannerTests: XCTestCase {
    
    // MARK: - Risk Level Tests
    
    func testSecurityRiskValues() {
        // Verify all security risk levels exist
        let risks: [SecurityScanner.SecurityRisk] = [.unknown, .low, .medium, .high, .critical]
        XCTAssertEqual(risks.count, 5)
    }
    
    func testKeyloggerRiskValues() {
        // Verify all keylogger risk levels exist
        let risks: [SecurityScanner.KeyloggerRisk] = [.none, .low, .medium, .high]
        XCTAssertEqual(risks.count, 4)
    }
    
    // MARK: - Warning Severity Tests
    
    func testWarningSeverityOrdering() {
        // Verify severity ordering
        XCTAssertLessThan(SecurityScanner.SecurityWarning.Severity.info, .low)
        XCTAssertLessThan(SecurityScanner.SecurityWarning.Severity.low, .medium)
        XCTAssertLessThan(SecurityScanner.SecurityWarning.Severity.medium, .high)
        XCTAssertLessThan(SecurityScanner.SecurityWarning.Severity.high, .critical)
    }
    
    // MARK: - Persistence Type Tests
    
    func testPersistenceTypesExist() {
        // Verify all persistence types exist
        let types: [SecurityScanner.PersistenceItem.PersistenceType] = [
            .launchAgent, .launchDaemon, .loginItem, .systemExtension, .browserExtension
        ]
        XCTAssertEqual(types.count, 5)
    }
}