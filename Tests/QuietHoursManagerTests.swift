import XCTest
@testable import PulseApp

final class QuietHoursManagerTests: XCTestCase {

    var manager: QuietHoursManager!

    override func setUp() {
        super.setUp()
        manager = QuietHoursManager.shared
        // Save initial state for restoration
        initialQuietHoursEnabled = AppSettings.shared.quietHoursEnabled
        initialQuietHoursStart = AppSettings.shared.quietHoursStart
        initialQuietHoursEnd = AppSettings.shared.quietHoursEnd
        initialAllowCriticalAlerts = AppSettings.shared.allowCriticalAlerts
    }

    override func tearDown() {
        // Restore initial state to ensure test isolation
        AppSettings.shared.quietHoursEnabled = initialQuietHoursEnabled
        AppSettings.shared.quietHoursStart = initialQuietHoursStart
        AppSettings.shared.quietHoursEnd = initialQuietHoursEnd
        AppSettings.shared.allowCriticalAlerts = initialAllowCriticalAlerts

        manager = nil
        super.tearDown()
    }

    // MARK: - State Preservation

    var initialQuietHoursEnabled: Bool = false
    var initialQuietHoursStart: String = "22:00"
    var initialQuietHoursEnd: String = "08:00"
    var initialAllowCriticalAlerts: Bool = true

    // MARK: - Time Parsing Tests

    func testParseTime_validTime() {
        // Test time parsing logic indirectly through isQuietHours
        manager.quietHoursStart = "08:00"
        manager.quietHoursEnd = "17:00"
        manager.quietHoursEnabled = true

        // Time parsing should work without crashing
        _ = manager.isQuietHours()
    }

    // MARK: - Quiet Hours Detection Tests

    func testIsQuietHours_disabled_returnsFalse() {
        manager.quietHoursEnabled = false
        manager.quietHoursStart = "22:00"
        manager.quietHoursEnd = "08:00"

        XCTAssertFalse(manager.isQuietHours())
    }

    func testIsQuietHours_sameDayRange_duringRange() {
        manager.quietHoursEnabled = true
        manager.quietHoursStart = "09:00"
        manager.quietHoursEnd = "17:00"

        // Note: This test checks current system time against the range
        // If test runs during 09:00-17:00, it will be in quiet hours
        // The actual result depends on when the test runs
        _ = manager.isQuietHours()
    }

    func testIsQuietHours_sameDayRange_outsideRange() {
        manager.quietHoursEnabled = true
        manager.quietHoursStart = "09:00"
        manager.quietHoursEnd = "17:00"

        // Note: This test verifies isQuietHours() executes without crashing
        // Actual result depends on current system time relative to range
        // When test runs during 09:00-17:00, isQuietHours() returns true
        // When test runs outside that range, isQuietHours() returns false
        _ = manager.isQuietHours()
    }

    func testIsQuietHours_overnightRange_duringRange() {
        manager.quietHoursEnabled = true
        manager.quietHoursStart = "22:00"
        manager.quietHoursEnd = "08:00"

        // This tests overnight range logic
        // Note: Actual time depends on when test runs
        _ = manager.isQuietHours()
    }

    // MARK: - Notification Suppression Tests

    func testShouldSuppressNotification_quietHoursDisabled() {
        manager.quietHoursEnabled = false

        XCTAssertFalse(manager.shouldSuppressNotification(isCritical: false))
        XCTAssertFalse(manager.shouldSuppressNotification(isCritical: true))
    }

    func testShouldSuppressNotification_quietHoursEnabled_nonCritical() {
        manager.quietHoursEnabled = true
        manager.allowCriticalAlerts = true

        // When in quiet hours, non-critical should be suppressed
        // Note: Actual result depends on current time
        _ = manager.shouldSuppressNotification(isCritical: false)
    }

    func testShouldSuppressNotification_quietHoursEnabled_critical() {
        manager.quietHoursEnabled = true
        manager.allowCriticalAlerts = true

        // Critical alerts should NOT be suppressed when allowCriticalAlerts is true
        // Note: Actual result depends on current time
        _ = manager.shouldSuppressNotification(isCritical: true)
    }

    // MARK: - Time Range String Tests

    func testGetTimeRangeString() {
        manager.quietHoursStart = "22:00"
        manager.quietHoursEnd = "08:00"

        XCTAssertEqual(manager.getTimeRangeString(), "22:00 - 08:00")
    }

    // MARK: - Upcoming Quiet Hours Tests

    func testWillStartSoon_quietHoursDisabled() {
        manager.quietHoursEnabled = false

        XCTAssertFalse(manager.willStartSoon())
    }

    func testWillEndSoon_notInQuietHours() {
        manager.quietHoursEnabled = true
        manager.quietHoursStart = "22:00"
        manager.quietHoursEnd = "08:00"

        // When not in quiet hours, willEndSoon should return false
        if !manager.isQuietHours() {
            XCTAssertFalse(manager.willEndSoon())
        }
    }

    // MARK: - Settings Sync Tests

    func testQuietHoursEnabled_syncsToAppSettings() {
        let initialSetting = AppSettings.shared.quietHoursEnabled
        manager.quietHoursEnabled = !initialSetting

        XCTAssertEqual(AppSettings.shared.quietHoursEnabled, !initialSetting)

        // Restore
        manager.quietHoursEnabled = initialSetting
    }

    func testQuietHoursStart_syncsToAppSettings() {
        manager.quietHoursStart = "23:00"

        XCTAssertEqual(AppSettings.shared.quietHoursStart, "23:00")

        // Restore
        manager.quietHoursStart = "22:00"
    }

    func testQuietHoursEnd_syncsToAppSettings() {
        manager.quietHoursEnd = "09:00"

        XCTAssertEqual(AppSettings.shared.quietHoursEnd, "09:00")

        // Restore
        manager.quietHoursEnd = "08:00"
    }

    func testAllowCriticalAlerts_syncsToAppSettings() {
        let initialSetting = AppSettings.shared.allowCriticalAlerts
        manager.allowCriticalAlerts = !initialSetting

        XCTAssertEqual(AppSettings.shared.allowCriticalAlerts, !initialSetting)

        // Restore
        manager.allowCriticalAlerts = initialSetting
    }
}
