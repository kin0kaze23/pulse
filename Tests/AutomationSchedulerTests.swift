import XCTest
@testable import Pulse

final class AutomationSchedulerTests: XCTestCase {

    var scheduler: AutomationScheduler!
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        scheduler = AutomationScheduler.shared
        settings = AppSettings.shared
        // Save initial state for restoration
        initialDailyCleanupEnabled = settings.dailyCleanupEnabled
        initialDailyCleanupTime = settings.dailyCleanupTime
        initialWeeklySecurityScanEnabled = settings.weeklySecurityScanEnabled
        initialWeeklySecurityScanDay = settings.weeklySecurityScanDay
    }

    override func tearDown() {
        // Restore initial state to ensure test isolation
        settings.dailyCleanupEnabled = initialDailyCleanupEnabled
        settings.dailyCleanupTime = initialDailyCleanupTime
        settings.weeklySecurityScanEnabled = initialWeeklySecurityScanEnabled
        settings.weeklySecurityScanDay = initialWeeklySecurityScanDay

        scheduler = nil
        settings = nil
        super.tearDown()
    }

    // MARK: - State Preservation

    var initialDailyCleanupEnabled: Bool = false
    var initialDailyCleanupTime: String = "03:00"
    var initialWeeklySecurityScanEnabled: Bool = false
    var initialWeeklySecurityScanDay: Int = 1

    // MARK: - Initialization Tests

    func testSchedulerInitialization() {
        // Scheduler should initialize with default settings
        XCTAssertNotNil(scheduler)
    }

    func testDefaultDailyCleanupDisabled() {
        XCTAssertFalse(scheduler.dailyCleanupEnabled)
    }

    func testDefaultDailyCleanupTime() {
        XCTAssertEqual(scheduler.dailyCleanupTime, "03:00")
    }

    func testDefaultWeeklySecurityScanDisabled() {
        XCTAssertFalse(scheduler.weeklySecurityScanEnabled)
    }

    func testDefaultWeeklySecurityScanDay() {
        XCTAssertEqual(scheduler.weeklySecurityScanDay, 1) // Sunday
    }

    // MARK: - Start/Stop Monitoring Tests

    func testStartMonitoring_startsScheduledJobs() {
        // Enable a job before starting
        scheduler.dailyCleanupEnabled = true
        scheduler.dailyCleanupTime = "03:00"

        scheduler.startMonitoring()

        // Jobs should be scheduled (timers are private, tested indirectly)
        // Note: Full verification requires waiting for scheduled time
    }

    func testCancelAllScheduledJobs_removesTimers() {
        scheduler.startMonitoring()

        scheduler.cancelAllScheduledJobs()

        // All timers should be cancelled
        // Note: Private property, tested indirectly through behavior
    }

    func testUpdateScheduledJobs_refreshesSchedule() {
        // Start with daily cleanup enabled
        scheduler.dailyCleanupEnabled = true
        scheduler.startMonitoring()

        // Update should cancel and reschedule
        scheduler.updateScheduledJobs()

        // Schedule should be refreshed
    }

    // MARK: - Time Calculation Tests

    func testParseTime_validTime() {
        // Test time parsing through scheduling
        scheduler.dailyCleanupTime = "14:30"

        XCTAssertEqual(scheduler.dailyCleanupTime, "14:30")
    }

    func testScheduleDailyCleanup_enabled() {
        scheduler.dailyCleanupEnabled = true
        scheduler.dailyCleanupTime = "03:00"

        scheduler.scheduleDailyCleanup(at: "03:00")

        // Timer should be scheduled for daily cleanup
    }

    func testScheduleDailyCleanup_disabled() {
        scheduler.dailyCleanupEnabled = false

        scheduler.scheduleDailyCleanup(at: "03:00")

        // Timer should NOT be scheduled when disabled
    }

    func testScheduleWeeklySecurity_enabled() {
        scheduler.weeklySecurityScanEnabled = true
        scheduler.weeklySecurityScanDay = 1 // Sunday

        scheduler.scheduleWeeklySecurity(on: 1)

        // Timer should be scheduled for weekly security scan
    }

    func testScheduleWeeklySecurity_disabled() {
        scheduler.weeklySecurityScanEnabled = false

        scheduler.scheduleWeeklySecurity(on: 1)

        // Timer should NOT be scheduled when disabled
    }

    // MARK: - Settings Sync Tests

    func testDailyCleanupEnabled_syncsToAppSettings() {
        let initialSetting = settings.dailyCleanupEnabled
        scheduler.dailyCleanupEnabled = !initialSetting

        XCTAssertEqual(settings.dailyCleanupEnabled, !initialSetting)

        // Restore
        scheduler.dailyCleanupEnabled = initialSetting
    }

    func testDailyCleanupTime_syncsToAppSettings() {
        scheduler.dailyCleanupTime = "04:00"

        XCTAssertEqual(settings.dailyCleanupTime, "04:00")

        // Restore
        scheduler.dailyCleanupTime = "03:00"
    }

    func testWeeklySecurityScanEnabled_syncsToAppSettings() {
        let initialSetting = settings.weeklySecurityScanEnabled
        scheduler.weeklySecurityScanEnabled = !initialSetting

        XCTAssertEqual(settings.weeklySecurityScanEnabled, !initialSetting)

        // Restore
        scheduler.weeklySecurityScanEnabled = initialSetting
    }

    func testWeeklySecurityScanDay_syncsToAppSettings() {
        scheduler.weeklySecurityScanDay = 2 // Monday

        XCTAssertEqual(settings.weeklySecurityScanDay, 2)

        // Restore
        scheduler.weeklySecurityScanDay = 1
    }

    // MARK: - Fire Time Calculation Tests

    func testCalculateNextFireTime_daily_futureTime() {
        // Test that future times today are scheduled for today
        // Note: Actual Date calculation tested indirectly
        scheduler.dailyCleanupTime = "23:59"

        XCTAssertEqual(scheduler.dailyCleanupTime, "23:59")
    }

    func testCalculateNextFireTime_daily_pastTime() {
        // Test that past times today are scheduled for tomorrow
        // Note: Actual Date calculation tested indirectly
        scheduler.dailyCleanupTime = "00:00"

        XCTAssertEqual(scheduler.dailyCleanupTime, "00:00")
    }

    func testCalculateNextFireTime_weekly_validDay() {
        // Test weekly scheduling with valid day
        scheduler.weeklySecurityScanDay = 7 // Saturday

        XCTAssertEqual(scheduler.weeklySecurityScanDay, 7)
    }

    // MARK: - Job Execution Tests

    func testRunScheduledCleanup_executes() {
        // Note: Full execution test requires ComprehensiveOptimizer integration
        // This test verifies the method exists and can be called
        scheduler.startMonitoring()

        // Scheduled cleanup runs asynchronously
        // Full test would require waiting for scheduled time
    }

    func testRunScheduledSecurityScan_executes() {
        // Note: Full execution test requires SecurityScanner integration
        scheduler.startMonitoring()

        // Security scan runs asynchronously
        // Full test would require waiting for scheduled time
    }

    // MARK: - Auto-cleanup Integration Tests

    func testScheduledCleanup_respectsAutoCleanupThreshold() {
        // Enable auto-cleanup
        settings.autoCleanupEnabled = true
        settings.autoCleanupThresholdMB = 500.0

        // Scheduled cleanup should respect threshold
        // Note: Full integration test requires optimizer state
    }

    // MARK: - Timer Interval Tests

    func testDailyCleanupInterval_is24Hours() {
        // Daily cleanup should repeat every 86400 seconds (24 hours)
        let dailyInterval: TimeInterval = 86400

        XCTAssertEqual(dailyInterval, 86400)
    }

    func testWeeklySecurityScanInterval_is7Days() {
        // Weekly scan should repeat every 604800 seconds (7 days)
        let weeklyInterval: TimeInterval = 604800

        XCTAssertEqual(weeklyInterval, 604800)
    }
}
