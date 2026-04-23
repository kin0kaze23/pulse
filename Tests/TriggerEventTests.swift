import XCTest
@testable import PulseApp

final class TriggerEventTests: XCTestCase {

    // MARK: - TriggerType Tests

    func testTriggerTypeAllCasesCount() {
        // Should have 8 trigger types
        XCTAssertEqual(TriggerType.allCases.count, 8)
    }

    func testTriggerTypeDisplayNames() {
        // Verify display names are non-empty
        for type in TriggerType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }

    func testTriggerTypeIcons() {
        // Verify icons are non-empty
        for type in TriggerType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    func testTriggerTypeCategories() {
        // All trigger types should have a category
        for type in TriggerType.allCases {
            XCTAssertNotNil(type.category)
        }
    }

    // MARK: - TriggerEvent Codable Tests

    func testTriggerEventCodable() throws {
        let event = TriggerEvent(
            type: .memoryHigh,
            value: 85.0,
            threshold: 80.0,
            freedMB: 150.5,
            success: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TriggerEvent.self, from: data)

        XCTAssertEqual(decoded.type, event.type)
        XCTAssertEqual(decoded.value, event.value)
        XCTAssertEqual(decoded.threshold, event.threshold)
        XCTAssertEqual(decoded.freedMB, event.freedMB)
        XCTAssertEqual(decoded.success, event.success)
    }

    func testTriggerEventWithProcessInfo() throws {
        let event = TriggerEvent(
            type: .stopMemoryHog,
            value: 95.0,
            processName: "Safari",
            processID: 12345,
            success: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TriggerEvent.self, from: data)

        XCTAssertEqual(decoded.processName, "Safari")
        XCTAssertEqual(decoded.processID, 12345)
    }

    func testTriggerEventWithFailure() throws {
        let event = TriggerEvent(
            type: .manualCleanup,
            success: false,
            errorMessage: "Permission denied"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TriggerEvent.self, from: data)

        XCTAssertFalse(decoded.success)
        XCTAssertEqual(decoded.errorMessage, "Permission denied")
    }

    // MARK: - TriggerStatistics Tests

    func testTriggerStatisticsCalculations() {
        let stats = TriggerStatistics(
            totalEvents: 100,
            todayEvents: 10,
            weekEvents: 50,
            successfulEvents: 95,
            failedEvents: 5,
            totalFreedMB: 1500.0
        )

        XCTAssertEqual(stats.totalEvents, 100)
        XCTAssertEqual(stats.todayEvents, 10)
        XCTAssertEqual(stats.weekEvents, 50)
        XCTAssertEqual(stats.successfulEvents, 95)
        XCTAssertEqual(stats.failedEvents, 5)
        XCTAssertEqual(stats.totalFreedMB, 1500.0)
    }

    func testTriggerStatisticsSuccessRate() {
        let stats = TriggerStatistics(
            totalEvents: 100,
            todayEvents: 10,
            weekEvents: 50,
            successfulEvents: 80,
            failedEvents: 20,
            totalFreedMB: 1000.0
        )

        XCTAssertEqual(stats.successRate, 80.0)
    }

    func testTriggerStatisticsZeroEvents() {
        let stats = TriggerStatistics(
            totalEvents: 0,
            todayEvents: 0,
            weekEvents: 0,
            successfulEvents: 0,
            failedEvents: 0,
            totalFreedMB: 0
        )

        XCTAssertEqual(stats.successRate, 0.0)
    }

    // MARK: - TriggerFilter Tests

    func testTriggerFilterAllCases() {
        let filters = TriggerFilter.allCases
        XCTAssertEqual(filters.count, 6)
    }

    func testTriggerFilterCategories() {
        XCTAssertNil(TriggerFilter.all.category)
        XCTAssertNil(TriggerFilter.today.category)
        XCTAssertNil(TriggerFilter.thisWeek.category)
        XCTAssertEqual(TriggerFilter.automation.category, .automation)
        XCTAssertEqual(TriggerFilter.scheduled.category, .scheduled)
        XCTAssertEqual(TriggerFilter.manual.category, .manual)
    }
}