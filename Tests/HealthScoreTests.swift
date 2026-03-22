import XCTest
@testable import Pulse

final class HealthScoreTests: XCTestCase {
    
    // MARK: - DesignSystem Color Tests
    
    func testScoreColorMapping() {
        // Test that DesignSystem.Colors.score() returns correct colors
        XCTAssertEqual(DesignSystem.Colors.score(95), .green)
        XCTAssertEqual(DesignSystem.Colors.score(85), .blue)
        XCTAssertEqual(DesignSystem.Colors.score(75), .yellow)
        XCTAssertEqual(DesignSystem.Colors.score(60), .orange)
        XCTAssertEqual(DesignSystem.Colors.score(40), .red)
    }
    
    func testBatteryColorWhenCharging() {
        // Battery should always be green when charging
        XCTAssertEqual(DesignSystem.Colors.battery(10, isCharging: true), .green)
        XCTAssertEqual(DesignSystem.Colors.battery(50, isCharging: true), .green)
        XCTAssertEqual(DesignSystem.Colors.battery(90, isCharging: true), .green)
    }
    
    func testBatteryColorWhenNotCharging() {
        // Battery should be green when > 20%, red otherwise
        XCTAssertEqual(DesignSystem.Colors.battery(30, isCharging: false), .green)
        XCTAssertEqual(DesignSystem.Colors.battery(10, isCharging: false), .red)
    }
    
    // MARK: - Brand Tests
    
    func testBrandName() {
        XCTAssertEqual(Brand.name, "Pulse")
    }
    
    func testBrandTagline() {
        XCTAssertEqual(Brand.shortTagline, "Keep your Mac in flow")
    }
    
    func testBrandCTA() {
        XCTAssertEqual(Brand.optimizeCTA, "Optimize Now")
    }
}