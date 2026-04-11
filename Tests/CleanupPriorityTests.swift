//
//  CleanupPriorityTests.swift
//  PulseTests
//
//  Unit tests for the CleanupPriority enum.
//

import XCTest
@testable import Pulse

final class CleanupPriorityTests: XCTestCase {

    // MARK: - Case Count

    func testAllCasesExist() {
        XCTAssertEqual(CleanupPriority.allCases.count, 4)
        XCTAssertTrue(CleanupPriority.allCases.contains(.high))
        XCTAssertTrue(CleanupPriority.allCases.contains(.medium))
        XCTAssertTrue(CleanupPriority.allCases.contains(.low))
        XCTAssertTrue(CleanupPriority.allCases.contains(.optional))
    }

    // MARK: - Raw Values

    func testRawValues() {
        XCTAssertEqual(CleanupPriority.high.rawValue, "High")
        XCTAssertEqual(CleanupPriority.medium.rawValue, "Medium")
        XCTAssertEqual(CleanupPriority.low.rawValue, "Low")
        XCTAssertEqual(CleanupPriority.optional.rawValue, "Optional")
    }

    // MARK: - Colors

    func testColors() {
        XCTAssertEqual(CleanupPriority.high.color, "green")
        XCTAssertEqual(CleanupPriority.medium.color, "yellow")
        XCTAssertEqual(CleanupPriority.low.color, "orange")
        XCTAssertEqual(CleanupPriority.optional.color, "gray")
    }

    // MARK: - Icons

    func testIcons() {
        XCTAssertEqual(CleanupPriority.high.icon, "checkmark.circle.fill")
        XCTAssertEqual(CleanupPriority.medium.icon, "exclamationmark.circle.fill")
        XCTAssertEqual(CleanupPriority.low.icon, "info.circle.fill")
        XCTAssertEqual(CleanupPriority.optional.icon, "questionmark.circle.fill")
    }

    // MARK: - Descriptions

    func testDescriptions() {
        XCTAssertTrue(CleanupPriority.high.description.contains("Safe"))
        XCTAssertTrue(CleanupPriority.medium.description.contains("Safe"))
        XCTAssertTrue(CleanupPriority.medium.description.contains("slowdown"))
        XCTAssertTrue(CleanupPriority.low.description.contains("Review"))
        XCTAssertTrue(CleanupPriority.optional.description.contains("discretion"))
    }

    // MARK: - Comparable

    func testPriorityOrdering() {
        // High should be greater than all others
        XCTAssertGreaterThan(CleanupPriority.high, CleanupPriority.medium)
        XCTAssertGreaterThan(CleanupPriority.high, CleanupPriority.low)
        XCTAssertGreaterThan(CleanupPriority.high, CleanupPriority.optional)

        // Medium should be greater than low and optional
        XCTAssertGreaterThan(CleanupPriority.medium, CleanupPriority.low)
        XCTAssertGreaterThan(CleanupPriority.medium, CleanupPriority.optional)

        // Low should be greater than optional
        XCTAssertGreaterThan(CleanupPriority.low, CleanupPriority.optional)
    }

    func testPriorityEquality() {
        XCTAssertEqual(CleanupPriority.high, CleanupPriority.high)
        XCTAssertEqual(CleanupPriority.medium, CleanupPriority.medium)
        XCTAssertEqual(CleanupPriority.low, CleanupPriority.low)
        XCTAssertEqual(CleanupPriority.optional, CleanupPriority.optional)

        XCTAssertNotEqual(CleanupPriority.high, CleanupPriority.medium)
        XCTAssertNotEqual(CleanupPriority.low, CleanupPriority.optional)
    }

    func testPrioritySorting() {
        let unsorted: [CleanupPriority] = [.optional, .high, .low, .medium]
        let sorted = unsorted.sorted()

        // sorted() uses < which puts less important first (lower sortOrder = more important)
        // Since < inverts sortOrder, sorted() gives most important first
        // Actual: ascending by rawValue = [.optional, .low, .medium, .high]
        // For descending (most important first), use sorted(by: >)
        XCTAssertEqual(sorted, [.optional, .low, .medium, .high])
        XCTAssertEqual(unsorted.sorted(by: >), [.high, .medium, .low, .optional])
    }

    // MARK: - Identifiable

    func testIdentifiable() {
        XCTAssertEqual(CleanupPriority.high.id, "High")
        XCTAssertEqual(CleanupPriority.medium.id, "Medium")
        XCTAssertEqual(CleanupPriority.low.id, "Low")
        XCTAssertEqual(CleanupPriority.optional.id, "Optional")
    }

    // MARK: - Codable

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for priority in CleanupPriority.allCases {
            let data = try encoder.encode(priority)
            let decoded = try decoder.decode(CleanupPriority.self, from: data)
            XCTAssertEqual(priority, decoded)
        }
    }

    func testCodableRawValues() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let data = try encoder.encode(CleanupPriority.high)
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"High\"")
    }
}
