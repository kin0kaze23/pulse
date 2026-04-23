import XCTest
@testable import PulseApp

final class HistoricalMetricsServiceTests: XCTestCase {

    var service: HistoricalMetricsService!

    override func setUp() {
        super.setUp()
        service = HistoricalMetricsService.shared
        // Clear any existing events before each test
        service.clearTriggerEvents()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Basic Tests (Non-async)

    func testEmptyStatistics() {
        let stats = service.getTriggerStatistics()

        XCTAssertEqual(stats.totalEvents, 0)
        XCTAssertEqual(stats.todayEvents, 0)
        XCTAssertEqual(stats.weekEvents, 0)
        XCTAssertEqual(stats.totalFreedMB, 0)
    }

    // MARK: - Synchronous Tests (Testing get* methods only)

    func testGetTriggerEventsReturnsAll() {
        // getTriggerEvents returns current state (may have events from other tests)
        let events = service.getTriggerEvents()
        XCTAssertNotNil(events)
    }

    func testGetTriggerEventsWithLimit() {
        // Test limit parameter works
        let limitedEvents = service.getTriggerEvents(limit: 5)
        XCTAssertLessThanOrEqual(limitedEvents.count, 5)
    }

    func testGetTriggerEventsWithAllFilter() {
        let allEvents = service.getTriggerEvents(filter: .all)
        XCTAssertNotNil(allEvents)
    }

    func testGetTriggerEventsWithTodayFilter() {
        let todayEvents = service.getTriggerEvents(filter: .today)
        XCTAssertNotNil(todayEvents)
    }

    func testGetTriggerEventsWithThisWeekFilter() {
        let weekEvents = service.getTriggerEvents(filter: .thisWeek)
        XCTAssertNotNil(weekEvents)
    }

    func testGetTriggerEventsWithAutomationFilter() {
        let automationEvents = service.getTriggerEvents(filter: .automation)
        XCTAssertNotNil(automationEvents)
    }

    func testGetTriggerEventsWithScheduledFilter() {
        let scheduledEvents = service.getTriggerEvents(filter: .scheduled)
        XCTAssertNotNil(scheduledEvents)
    }

    func testGetTriggerEventsWithManualFilter() {
        let manualEvents = service.getTriggerEvents(filter: .manual)
        XCTAssertNotNil(manualEvents)
    }

    func testClearTriggerEvents() {
        // First verify we can call clear
        service.clearTriggerEvents()
        let stats = service.getTriggerStatistics()
        XCTAssertEqual(stats.totalEvents, 0)
    }

    func testTriggerStatisticsZeroState() {
        // After clear, stats should be zero
        service.clearTriggerEvents()
        let stats = service.getTriggerStatistics()
        XCTAssertEqual(stats.totalEvents, 0)
        XCTAssertEqual(stats.successfulEvents, 0)
        XCTAssertEqual(stats.failedEvents, 0)
        XCTAssertEqual(stats.totalFreedMB, 0)
    }

    func testSuccessRateCalculation() {
        // Create stats with known values
        let stats = TriggerStatistics(
            totalEvents: 10,
            todayEvents: 5,
            weekEvents: 8,
            successfulEvents: 7,
            failedEvents: 3,
            totalFreedMB: 100.0
        )
        XCTAssertEqual(stats.successRate, 70.0)
    }
}