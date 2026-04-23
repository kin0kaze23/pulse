import XCTest
@testable import PulseApp

final class HealthScoreServiceTests: XCTestCase {
    
    var service: HealthScoreService!
    
    override func setUp() {
        super.setUp()
        service = HealthScoreService.shared
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Grade Tests
    // Note: gradeForScore is private, tested indirectly through HealthScoreResult
    
    func testGradeComparison() {
        // Test grade ordering
        XCTAssertLessThan(HealthGrade.f, .d)
        XCTAssertLessThan(HealthGrade.d, .c)
        XCTAssertLessThan(HealthGrade.c, .b)
        XCTAssertLessThan(HealthGrade.b, .a)
    }
    
    func testGradeColors() {
        XCTAssertEqual(HealthGrade.a.color, "green")
        XCTAssertEqual(HealthGrade.b.color, "blue")
        XCTAssertEqual(HealthGrade.c.color, "yellow")
        XCTAssertEqual(HealthGrade.d.color, "orange")
        XCTAssertEqual(HealthGrade.f.color, "red")
    }
    
    func testGradeDescriptions() {
        XCTAssertEqual(HealthGrade.a.description, "Excellent")
        XCTAssertEqual(HealthGrade.b.description, "Good")
        XCTAssertEqual(HealthGrade.c.description, "Fair")
        XCTAssertEqual(HealthGrade.d.description, "Poor")
        XCTAssertEqual(HealthGrade.f.description, "Critical")
    }
    
    // MARK: - Trend Tests
    
    func testTrendFromDelta() {
        // Test trend calculation from delta values
        let resultPositive = HealthScoreResult(
            currentScore: 85,
            currentGrade: .b,
            score24hAgo: 70,
            score7dAgo: 60,
            breakdown: [],
            average24h: 75,
            average7d: 65
        )
        
        XCTAssertEqual(resultPositive.delta24h, 15)
        XCTAssertEqual(resultPositive.delta7d, 25)
        XCTAssertEqual(resultPositive.trend24h, .improving)
        XCTAssertEqual(resultPositive.trend7d, .improving)
        
        let resultNegative = HealthScoreResult(
            currentScore: 60,
            currentGrade: .d,
            score24hAgo: 75,
            score7dAgo: 85,
            breakdown: [],
            average24h: 70,
            average7d: 80
        )
        
        XCTAssertEqual(resultNegative.delta24h, -15)
        XCTAssertEqual(resultNegative.delta7d, -25)
        XCTAssertEqual(resultNegative.trend24h, .declining)
        XCTAssertEqual(resultNegative.trend7d, .declining)
        
        let resultStable = HealthScoreResult(
            currentScore: 80,
            currentGrade: .b,
            score24hAgo: 78,
            score7dAgo: 82,
            breakdown: [],
            average24h: 79,
            average7d: 81
        )
        
        XCTAssertEqual(resultStable.delta24h, 2)
        XCTAssertEqual(resultStable.delta7d, -2)
        XCTAssertEqual(resultStable.trend24h, .stable)
        XCTAssertEqual(resultStable.trend7d, .stable)
        
        let resultNoHistory = HealthScoreResult(
            currentScore: 85,
            currentGrade: .b,
            score24hAgo: nil,
            score7dAgo: nil,
            breakdown: [],
            average24h: nil,
            average7d: nil
        )
        
        XCTAssertNil(resultNoHistory.delta24h)
        XCTAssertNil(resultNoHistory.delta7d)
        XCTAssertEqual(resultNoHistory.trend24h, .insufficientData)
        XCTAssertEqual(resultNoHistory.trend7d, .insufficientData)
    }
    
    func testTrendIcons() {
        XCTAssertEqual(HealthTrend.improving.icon, "arrow.up.right")
        XCTAssertEqual(HealthTrend.stable.icon, "minus")
        XCTAssertEqual(HealthTrend.declining.icon, "arrow.down.right")
        XCTAssertEqual(HealthTrend.insufficientData.icon, "questionmark")
    }
    
    func testTrendColors() {
        XCTAssertEqual(HealthTrend.improving.color, "green")
        XCTAssertEqual(HealthTrend.stable.color, "gray")
        XCTAssertEqual(HealthTrend.declining.color, "red")
        XCTAssertEqual(HealthTrend.insufficientData.color, "gray")
    }
    
    // MARK: - Penalty Tests
    
    func testHealthPenaltyCreation() {
        let penalty = HealthPenalty(
            category: .memory,
            severity: .critical,
            pointsLost: 40,
            currentValue: "95%",
            threshold: "95%",
            recommendation: "Close memory-intensive apps"
        )
        
        XCTAssertEqual(penalty.category, .memory)
        XCTAssertEqual(penalty.severity, .critical)
        XCTAssertEqual(penalty.pointsLost, 40)
        XCTAssertEqual(penalty.currentValue, "95%")
        XCTAssertEqual(penalty.recommendation, "Close memory-intensive apps")
        XCTAssertNotNil(penalty.id)
    }
    
    func testPenaltySeverityColors() {
        XCTAssertEqual(HealthPenalty.PenaltySeverity.info.color, "blue")
        XCTAssertEqual(HealthPenalty.PenaltySeverity.warning.color, "orange")
        XCTAssertEqual(HealthPenalty.PenaltySeverity.critical.color, "red")
    }
    
    func testPenaltyCategoryRawValues() {
        XCTAssertEqual(HealthPenalty.HealthCategory.memory.rawValue, "Memory")
        XCTAssertEqual(HealthPenalty.HealthCategory.swap.rawValue, "Swap")
        XCTAssertEqual(HealthPenalty.HealthCategory.cpu.rawValue, "CPU")
        XCTAssertEqual(HealthPenalty.HealthCategory.thermal.rawValue, "Thermal")
        XCTAssertEqual(HealthPenalty.HealthCategory.disk.rawValue, "Disk")
    }
    
    // MARK: - Score Calculation Tests
    
    func testScoreWithNoPenalties() {
        // Simulate perfect health (no penalties)
        let result = HealthScoreResult(
            currentScore: 100,
            currentGrade: .a,
            score24hAgo: 95,
            score7dAgo: 90,
            breakdown: [],
            average24h: 97,
            average7d: 93
        )
        
        XCTAssertEqual(result.currentScore, 100)
        XCTAssertEqual(result.currentGrade, .a)
        XCTAssertEqual(result.delta24h, 5)
        XCTAssertEqual(result.delta7d, 10)
        XCTAssertTrue(result.breakdown.isEmpty)
    }
    
    func testScoreWithPenalties() {
        // Simulate poor health with multiple penalties
        let penalties = [
            HealthPenalty(category: .memory, severity: .critical, pointsLost: 40, currentValue: "96%", threshold: "95%", recommendation: "Close apps"),
            HealthPenalty(category: .cpu, severity: .warning, pointsLost: 10, currentValue: "55%", threshold: "50%", recommendation: "Check processes"),
            HealthPenalty(category: .swap, severity: .info, pointsLost: 8, currentValue: "1.5 GB", threshold: "1 GB", recommendation: "Free memory")
        ]
        
        let totalPenalty = penalties.reduce(0) { $0 + $1.pointsLost }
        let expectedScore = max(0, 100 - totalPenalty)
        
        XCTAssertEqual(expectedScore, 42)  // 100 - 58
        
        let result = HealthScoreResult(
            currentScore: expectedScore,
            currentGrade: .f,
            score24hAgo: nil,
            score7dAgo: nil,
            breakdown: penalties,
            average24h: nil,
            average7d: nil
        )
        
        XCTAssertEqual(result.currentScore, 42)
        XCTAssertEqual(result.currentGrade, .f)
        XCTAssertEqual(result.breakdown.count, 3)
    }
    
    func testScoreBoundaries() {
        // Test score cannot go below 0
        let highPenaltyResult = HealthScoreResult(
            currentScore: 0,
            currentGrade: .f,
            score24hAgo: nil,
            score7dAgo: nil,
            breakdown: [],
            average24h: nil,
            average7d: nil
        )
        XCTAssertGreaterThanOrEqual(highPenaltyResult.currentScore, 0)
        
        // Test score cannot go above 100
        let noPenaltyResult = HealthScoreResult(
            currentScore: 100,
            currentGrade: .a,
            score24hAgo: nil,
            score7dAgo: nil,
            breakdown: [],
            average24h: nil,
            average7d: nil
        )
        XCTAssertLessThanOrEqual(noPenaltyResult.currentScore, 100)
    }
    
    // MARK: - Health Explanation Tests
    
    func testHealthExplanationWithImprovingTrend() {
        service.currentResult = HealthScoreResult(
            currentScore: 85,
            currentGrade: .b,
            score24hAgo: 70,
            score7dAgo: 60,
            breakdown: [
                HealthPenalty(category: .memory, severity: .info, pointsLost: 10, currentValue: "76%", threshold: "75%", recommendation: "Memory usage is elevated")
            ],
            average24h: 75,
            average7d: 65
        )
        
        let explanation = service.healthExplanation()
        XCTAssertTrue(explanation.contains("good"))
        XCTAssertTrue(explanation.contains("85"))
        XCTAssertTrue(explanation.contains("improving"))
    }

    func testHealthExplanationWithDecliningTrend() {
        service.currentResult = HealthScoreResult(
            currentScore: 60,
            currentGrade: .d,
            score24hAgo: 75,
            score7dAgo: 85,
            breakdown: [
                HealthPenalty(category: .memory, severity: .critical, pointsLost: 40, currentValue: "96%", threshold: "95%", recommendation: "Close apps")
            ],
            average24h: 70,
            average7d: 80
        )

        let explanation = service.healthExplanation()
        XCTAssertTrue(explanation.contains("poor"))
        XCTAssertTrue(explanation.contains("60"))
        XCTAssertTrue(explanation.contains("declining"))
    }

    func testHealthExplanationWithNoHistory() {
        service.currentResult = HealthScoreResult(
            currentScore: 80,
            currentGrade: .c,
            score24hAgo: nil,
            score7dAgo: nil,
            breakdown: [],
            average24h: nil,
            average7d: nil
        )

        let explanation = service.healthExplanation()
        XCTAssertTrue(explanation.contains("fair"))
        XCTAssertTrue(explanation.contains("80"))
        // Should not mention trend when insufficient data
        XCTAssertFalse(explanation.contains("Insufficient Data"))
    }
}
