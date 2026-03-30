//
//  HealthScoreTrendTests.swift
//  PulseTests
//
//  Tests for health score trend calculation and display
//

import XCTest
@testable import Pulse

final class HealthScoreTrendTests: XCTestCase {

    // MARK: - HealthTrend Enum Tests

    func testTrendIcon_Improving() {
        XCTAssertEqual(HealthTrend.improving.compactIcon, "arrow.up")
        XCTAssertEqual(HealthTrend.improving.icon, "arrow.up.right")
    }

    func testTrendIcon_Stable() {
        XCTAssertEqual(HealthTrend.stable.compactIcon, "minus")
        XCTAssertEqual(HealthTrend.stable.icon, "minus")
    }

    func testTrendIcon_Declining() {
        XCTAssertEqual(HealthTrend.declining.compactIcon, "arrow.down")
        XCTAssertEqual(HealthTrend.declining.icon, "arrow.down.right")
    }

    func testTrendIcon_InsufficientData() {
        XCTAssertEqual(HealthTrend.insufficientData.compactIcon, "questionmark")
        XCTAssertEqual(HealthTrend.insufficientData.icon, "questionmark")
    }

    // MARK: - HealthTrend Color Tests

    func testTrendColor_Improving() {
        XCTAssertEqual(HealthTrend.improving.color, "green")
    }

    func testTrendColor_Stable() {
        XCTAssertEqual(HealthTrend.stable.color, "gray")
    }

    func testTrendColor_Declining() {
        XCTAssertEqual(HealthTrend.declining.color, "red")
    }

    func testTrendColor_InsufficientData() {
        XCTAssertEqual(HealthTrend.insufficientData.color, "gray")
    }

    // MARK: - HealthTrend Sign Prefix Tests

    func testSignFor_PositiveDelta() {
        XCTAssertEqual(HealthTrend.improving.signFor(delta: 5), "+")
        XCTAssertEqual(HealthTrend.improving.signFor(delta: 10), "+")
    }

    func testSignFor_NegativeDelta() {
        XCTAssertEqual(HealthTrend.declining.signFor(delta: -5), "")
        XCTAssertEqual(HealthTrend.declining.signFor(delta: -10), "")
    }

    func testSignFor_ZeroDelta() {
        XCTAssertEqual(HealthTrend.stable.signFor(delta: 0), "")
    }

    // MARK: - HealthScoreResult Trend Tests

    func testDelta24h_Calculation() {
        let result = HealthScoreResult(
            currentScore: 85,
            currentGrade: .a,
            score24hAgo: 75,
            score7dAgo: 70,
            breakdown: [],
            average24h: 80,
            average7d: 77
        )

        XCTAssertEqual(result.delta24h, 10)  // 85 - 75 = +10
    }

    func testDelta7d_Calculation() {
        let result = HealthScoreResult(
            currentScore: 85,
            currentGrade: .a,
            score24hAgo: 75,
            score7dAgo: 70,
            breakdown: [],
            average24h: 80,
            average7d: 77
        )

        XCTAssertEqual(result.delta7d, 15)  // 85 - 70 = +15
    }

    func testTrend24h_Improving() {
        let result = HealthScoreResult(
            currentScore: 90,
            currentGrade: .a,
            score24hAgo: 75,  // delta = +15
            score7dAgo: 70,
            breakdown: [],
            average24h: 82,
            average7d: 80
        )

        XCTAssertEqual(result.trend24h, .improving)
    }

    func testTrend24h_Declining() {
        let result = HealthScoreResult(
            currentScore: 60,
            currentGrade: .d,
            score24hAgo: 75,  // delta = -15
            score7dAgo: 70,
            breakdown: [],
            average24h: 67,
            average7d: 65
        )

        XCTAssertEqual(result.trend24h, .declining)
    }

    func testTrend24h_Stable() {
        let result = HealthScoreResult(
            currentScore: 80,
            currentGrade: .b,
            score24hAgo: 78,  // delta = +2 (within ±5 threshold)
            score7dAgo: 75,
            breakdown: [],
            average24h: 79,
            average7d: 77
        )

        XCTAssertEqual(result.trend24h, .stable)
    }

    func testTrend7d_InsufficientData() {
        let result = HealthScoreResult(
            currentScore: 85,
            currentGrade: .a,
            score24hAgo: nil,  // No 24h data
            score7dAgo: nil,   // No 7d data
            breakdown: [],
            average24h: nil,
            average7d: nil
        )

        XCTAssertEqual(result.trend7d, .insufficientData)
    }

    // MARK: - Edge Cases

    func testDelta_ExactlyFive() {
        let result = HealthScoreResult(
            currentScore: 85,
            currentGrade: .a,
            score24hAgo: 80,  // delta = +5 (boundary)
            score7dAgo: 75,
            breakdown: [],
            average24h: 82,
            average7d: 80
        )

        // +5 should be stable (threshold is >5 for improving)
        XCTAssertEqual(result.trend24h, .stable)
    }

    func testDelta_ExactlyNegativeFive() {
        let result = HealthScoreResult(
            currentScore: 75,
            currentGrade: .c,
            score24hAgo: 80,  // delta = -5 (boundary)
            score7dAgo: 85,
            breakdown: [],
            average24h: 77,
            average7d: 80
        )

        // -5 should be stable (threshold is <-5 for declining)
        XCTAssertEqual(result.trend24h, .stable)
    }

    func testDelta_LargePositive() {
        let result = HealthScoreResult(
            currentScore: 95,
            currentGrade: .a,
            score24hAgo: 50,  // delta = +45
            score7dAgo: 45,
            breakdown: [],
            average24h: 72,
            average7d: 70
        )

        XCTAssertEqual(result.trend24h, .improving)
        XCTAssertEqual(result.delta24h, 45)
    }

    func testDelta_LargeNegative() {
        let result = HealthScoreResult(
            currentScore: 30,
            currentGrade: .f,
            score24hAgo: 80,  // delta = -50
            score7dAgo: 85,
            breakdown: [],
            average24h: 55,
            average7d: 57
        )

        XCTAssertEqual(result.trend24h, .declining)
        XCTAssertEqual(result.delta24h, -50)
    }

    // MARK: - Grade Color Tests

    func testGradeColor() {
        XCTAssertEqual(HealthGrade.a.color, "green")
        XCTAssertEqual(HealthGrade.b.color, "blue")
        XCTAssertEqual(HealthGrade.c.color, "yellow")
        XCTAssertEqual(HealthGrade.d.color, "orange")
        XCTAssertEqual(HealthGrade.f.color, "red")
    }

    // MARK: - Grade Comparison Tests

    func testGradeOrdering() {
        XCTAssertTrue(HealthGrade.a > HealthGrade.b)
        XCTAssertTrue(HealthGrade.b > HealthGrade.c)
        XCTAssertTrue(HealthGrade.c > HealthGrade.d)
        XCTAssertTrue(HealthGrade.d > HealthGrade.f)
    }
}
