import XCTest
@testable import Pulse

final class AppSettingsTests: XCTestCase {
    
    // MARK: - Alert Threshold Tests
    
    func testDefaultAlertThresholdsCount() {
        // Default thresholds should have exactly 3 values
        XCTAssertEqual(AppSettings.defaultAlertThresholds.count, 3)
    }
    
    func testDefaultAlertThresholdsPercentages() {
        // Default thresholds should be 80, 90, 95
        let percentages = AppSettings.defaultAlertThresholds.map { $0.percentage }
        XCTAssertEqual(percentages.sorted(), [80.0, 90.0, 95.0])
    }
    
    // MARK: - Memory Unit Tests
    
    func testMemoryUnitsExist() {
        // Verify memory unit options exist
        let units: [AppSettings.MemoryUnit] = [.gb, .mb]
        XCTAssertEqual(units.count, 2)
    }
    
    // MARK: - Menu Bar Display Mode Tests
    
    func testMenuBarDisplayModesExist() {
        // Verify display mode options exist
        let modes: [AppSettings.MenuBarDisplayMode] = [.memoryPercent, .memoryGB, .cpuPercent, .compact]
        XCTAssertEqual(modes.count, 4)
    }
    
    // MARK: - Settings Singleton Tests
    
    func testSettingsSingleton() {
        // Settings should be a singleton
        let settings1 = AppSettings.shared
        let settings2 = AppSettings.shared
        XCTAssertTrue(settings1 === settings2)
    }
}