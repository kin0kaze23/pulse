//
//  HealthScoreService.swift
//  Pulse
//
//  Health score calculation with historical trend analysis
//  Provides current score, 24h/7d deltas, and metric-level breakdown
//

import Foundation
import Combine

// MARK: - Time Range Enum

enum HealthTimeRange {
    case last1Hour
    case last6Hours
    case last24Hours
    case lastWeek
    
    var seconds: TimeInterval {
        switch self {
        case .last1Hour: return 1 * 60 * 60
        case .last6Hours: return 6 * 60 * 60
        case .last24Hours: return 24 * 60 * 60
        case .lastWeek: return 7 * 24 * 60 * 60
        }
    }
}

// MARK: - Health Score Models

/// Health score with trend information
struct HealthScoreResult {
    /// Current health score (0-100)
    let currentScore: Int
    
    /// Current grade (A-F)
    let currentGrade: HealthGrade
    
    /// Score 24 hours ago (nil if insufficient history)
    let score24hAgo: Int?
    
    /// Score 7 days ago (nil if insufficient history)
    let score7dAgo: Int?
    
    /// Change in score over 24 hours (positive = improved)
    var delta24h: Int? {
        guard let score24h = score24hAgo else { return nil }
        return currentScore - score24h
    }
    
    /// Change in score over 7 days (positive = improved)
    var delta7d: Int? {
        guard let score7d = score7dAgo else { return nil }
        return currentScore - score7d
    }
    
    /// Trend direction over 24 hours
    var trend24h: HealthTrend {
        guard let delta = delta24h else { return .insufficientData }
        if delta > 5 { return .improving }
        if delta < -5 { return .declining }
        return .stable
    }
    
    /// Trend direction over 7 days
    var trend7d: HealthTrend {
        guard let delta = delta7d else { return .insufficientData }
        if delta > 5 { return .improving }
        if delta < -5 { return .declining }
        return .stable
    }
    
    /// Detailed breakdown of penalties
    let breakdown: [HealthPenalty]
    
    /// Average score over last 24 hours
    let average24h: Double?
    
    /// Average score over last 7 days
    let average7d: Double?
}

/// Health grade (A-F)
enum HealthGrade: String, Comparable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
    
    static func < (lhs: HealthGrade, rhs: HealthGrade) -> Bool {
        let order: [HealthGrade] = [.f, .d, .c, .b, .a]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
    
    /// Color for UI display
    var color: String {
        switch self {
        case .a: return "green"
        case .b: return "blue"
        case .c: return "yellow"
        case .d: return "orange"
        case .f: return "red"
        }
    }
    
    /// Description for UI
    var description: String {
        switch self {
        case .a: return "Excellent"
        case .b: return "Good"
        case .c: return "Fair"
        case .d: return "Poor"
        case .f: return "Critical"
        }
    }
}

/// Health trend direction
enum HealthTrend: String {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
    case insufficientData = "Insufficient Data"

    /// Icon for UI display
    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "minus"
        case .declining: return "arrow.down.right"
        case .insufficientData: return "questionmark"
        }
    }

    /// Compact icon for small displays (just arrow direction)
    var compactIcon: String {
        switch self {
        case .improving: return "arrow.up"
        case .stable: return "minus"
        case .declining: return "arrow.down"
        case .insufficientData: return "questionmark"
        }
    }

    /// Color for UI display
    var color: String {
        switch self {
        case .improving: return "green"
        case .stable: return "gray"
        case .declining: return "red"
        case .insufficientData: return "gray"
        }
    }

    /// Sign prefix for delta display (+/-)
    func signFor(delta: Int) -> String {
        if delta > 0 { return "+" }
        if delta < 0 { return "" }
        return ""
    }
}

/// Penalty for a specific health metric
struct HealthPenalty: Identifiable, Codable {
    let id: UUID
    let category: HealthCategory
    let severity: PenaltySeverity
    let pointsLost: Int
    let currentValue: String
    let threshold: String
    let recommendation: String
    
    init(id: UUID = UUID(), category: HealthCategory, severity: PenaltySeverity, pointsLost: Int, currentValue: String, threshold: String, recommendation: String) {
        self.id = id
        self.category = category
        self.severity = severity
        self.pointsLost = pointsLost
        self.currentValue = currentValue
        self.threshold = threshold
        self.recommendation = recommendation
    }
    
    enum HealthCategory: String, Codable {
        case memory = "Memory"
        case swap = "Swap"
        case cpu = "CPU"
        case thermal = "Thermal"
        case disk = "Disk"
    }
    
    enum PenaltySeverity: String, Codable {
        case info = "Info"
        case warning = "Warning"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
}

// MARK: - Health Score Service

/// Calculates health score with historical trend analysis
class HealthScoreService: ObservableObject {
    static let shared = HealthScoreService()
    
    @Published var currentResult: HealthScoreResult?
    @Published var isCalculating = false
    @Published var lastCalculated: Date?
    
    private let historicalService = HistoricalMetricsService.shared
    private let systemMonitor = SystemMemoryMonitor.shared
    private let cpuMonitor = CPUMonitor.shared
    private let healthMonitor = SystemHealthMonitor.shared
    private let diskMonitor = DiskMonitor.shared
    
    // Thresholds for score calculation
    private struct Thresholds {
        // Memory thresholds (percentage)
        static let memoryCritical: Double = 95
        static let memoryHigh: Double = 85
        static let memoryModerate: Double = 75
        
        // Swap thresholds (GB)
        static let swapCritical: Double = 5
        static let swapHigh: Double = 2
        static let swapModerate: Double = 1
        
        // CPU thresholds (percentage)
        static let cpuCritical: Double = 80
        static let cpuHigh: Double = 50
        
        // Disk thresholds (percentage)
        static let diskCritical: Double = 95
        static let diskHigh: Double = 90
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Calculate current health score with trends
    func calculateScore() {
        isCalculating = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Calculate current score
            let currentScore = self.calculateCurrentScore()
            let breakdown = self.calculateBreakdown()
            
            // Calculate historical scores
            let score24hAgo = self.calculateHistoricalScore(hours: 24)
            let score7dAgo = self.calculateHistoricalScore(hours: 24 * 7)
            
            // Calculate averages
            let average24h = self.calculateAverageScore(hours: 24)
            let average7d = self.calculateAverageScore(hours: 24 * 7)
            
            DispatchQueue.main.async {
                self.currentResult = HealthScoreResult(
                    currentScore: currentScore,
                    currentGrade: self.gradeForScore(currentScore),
                    score24hAgo: score24hAgo,
                    score7dAgo: score7dAgo,
                    breakdown: breakdown,
                    average24h: average24h,
                    average7d: average7d
                )
                self.lastCalculated = Date()
                self.isCalculating = false
            }
        }
    }
    
    /// Get human-readable explanation of current health
    func healthExplanation() -> String {
        guard let result = currentResult else {
            return "Calculating health score..."
        }
        
        let grade = result.currentGrade
        let score = result.currentScore
        
        var explanation = "Your Mac is running \(grade.description.lowercased()) (Score: \(score)/100)."
        
        // Add trend information
        if let trend24h = trendDescription(result.trend24h) {
            explanation += " \(trend24h)"
        }
        
        // Add top penalty if any
        if let topPenalty = result.breakdown.first {
            explanation += " \(topPenalty.recommendation)"
        }
        
        return explanation
    }
    
    // MARK: - Private Methods
    
    /// Calculate current health score from live metrics
    private func calculateCurrentScore() -> Int {
        let breakdown = calculateBreakdown()
        let totalPenalty = breakdown.reduce(0) { $0 + $1.pointsLost }
        return max(0, 100 - totalPenalty)
    }
    
    /// Calculate penalty breakdown from current metrics
    private func calculateBreakdown() -> [HealthPenalty] {
        var penalties: [HealthPenalty] = []
        
        // Memory penalty
        if let mem = systemMonitor.currentMemory {
            if mem.usedPercentage > Thresholds.memoryCritical {
                penalties.append(HealthPenalty(
                    category: .memory,
                    severity: .critical,
                    pointsLost: 40,
                    currentValue: String(format: "%.0f%%", mem.usedPercentage),
                    threshold: String(format: "%.0f%%", Thresholds.memoryCritical),
                    recommendation: "Close memory-intensive apps to reduce pressure"
                ))
            } else if mem.usedPercentage > Thresholds.memoryHigh {
                penalties.append(HealthPenalty(
                    category: .memory,
                    severity: .warning,
                    pointsLost: 25,
                    currentValue: String(format: "%.0f%%", mem.usedPercentage),
                    threshold: String(format: "%.0f%%", Thresholds.memoryHigh),
                    recommendation: "Consider closing unused applications"
                ))
            } else if mem.usedPercentage > Thresholds.memoryModerate {
                penalties.append(HealthPenalty(
                    category: .memory,
                    severity: .info,
                    pointsLost: 10,
                    currentValue: String(format: "%.0f%%", mem.usedPercentage),
                    threshold: String(format: "%.0f%%", Thresholds.memoryModerate),
                    recommendation: "Memory usage is elevated but acceptable"
                ))
            }
            
            // Swap penalty
            if mem.swapUsedGB > Thresholds.swapCritical {
                penalties.append(HealthPenalty(
                    category: .swap,
                    severity: .critical,
                    pointsLost: 20,
                    currentValue: String(format: "%.1f GB", mem.swapUsedGB),
                    threshold: String(format: "%.0f GB", Thresholds.swapCritical),
                    recommendation: "High swap usage indicates memory pressure - close apps or restart"
                ))
            } else if mem.swapUsedGB > Thresholds.swapHigh {
                penalties.append(HealthPenalty(
                    category: .swap,
                    severity: .warning,
                    pointsLost: 15,
                    currentValue: String(format: "%.1f GB", mem.swapUsedGB),
                    threshold: String(format: "%.0f GB", Thresholds.swapHigh),
                    recommendation: "Swap usage is high - consider freeing memory"
                ))
            } else if mem.swapUsedGB > Thresholds.swapModerate {
                penalties.append(HealthPenalty(
                    category: .swap,
                    severity: .info,
                    pointsLost: 8,
                    currentValue: String(format: "%.1f GB", mem.swapUsedGB),
                    threshold: String(format: "%.0f GB", Thresholds.swapModerate),
                    recommendation: "Some swap usage is normal"
                ))
            }
        }
        
        // CPU penalty
        let cpuTotal = cpuMonitor.userCPUPercentage + cpuMonitor.systemCPUPercentage
        if cpuTotal > Thresholds.cpuCritical {
            penalties.append(HealthPenalty(
                category: .cpu,
                severity: .critical,
                pointsLost: 20,
                currentValue: String(format: "%.0f%%", cpuTotal),
                threshold: String(format: "%.0f%%", Thresholds.cpuCritical),
                recommendation: "CPU is overloaded - identify and quit demanding processes"
            ))
        } else if cpuTotal > Thresholds.cpuHigh {
            penalties.append(HealthPenalty(
                category: .cpu,
                severity: .warning,
                pointsLost: 10,
                currentValue: String(format: "%.0f%%", cpuTotal),
                threshold: String(format: "%.0f%%", Thresholds.cpuHigh),
                recommendation: "CPU usage is elevated"
            ))
        }
        
        // Thermal penalty
        let thermalState = healthMonitor.thermalState
        if thermalState == "Critical" {
            penalties.append(HealthPenalty(
                category: .thermal,
                severity: .critical,
                pointsLost: 25,
                currentValue: thermalState,
                threshold: "Nominal",
                recommendation: "Mac is overheating - improve ventilation and close demanding apps"
            ))
        } else if thermalState == "Serious" {
            penalties.append(HealthPenalty(
                category: .thermal,
                severity: .warning,
                pointsLost: 15,
                currentValue: thermalState,
                threshold: "Nominal",
                recommendation: "Mac is running hot - check ventilation"
            ))
        }
        
        // Disk penalty
        if let disk = diskMonitor.primaryDisk {
            if disk.usedPercentage > Thresholds.diskCritical {
                penalties.append(HealthPenalty(
                    category: .disk,
                    severity: .critical,
                    pointsLost: 15,
                    currentValue: String(format: "%.0f%%", disk.usedPercentage),
                    threshold: String(format: "%.0f%%", Thresholds.diskCritical),
                    recommendation: "Disk is nearly full - free up space immediately"
                ))
            } else if disk.usedPercentage > Thresholds.diskHigh {
                penalties.append(HealthPenalty(
                    category: .disk,
                    severity: .warning,
                    pointsLost: 10,
                    currentValue: String(format: "%.0f%%", disk.usedPercentage),
                    threshold: String(format: "%.0f%%", Thresholds.diskHigh),
                    recommendation: "Disk space is running low"
                ))
            }
        }
        
        // Sort by severity (critical first)
        return penalties.sorted { penalty1, penalty2 in
            penalty1.severity.rawValue > penalty2.severity.rawValue
        }
    }
    
    /// Calculate health score from historical data
    private func calculateHistoricalScore(hours: Int) -> Int? {
        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
        let metrics = historicalService.metrics.filter { $0.timestamp >= cutoffDate }
        guard !metrics.isEmpty else { return nil }
        
        // Calculate average metrics over the period
        let avgMemoryPercent = metrics.map { $0.memoryUsedPercent }.reduce(0, +) / Double(metrics.count)
        let avgSwapGB = metrics.map { $0.swapUsedGB }.reduce(0, +) / Double(metrics.count)
        let avgCPUPercent = metrics.map { $0.cpuUsagePercent }.reduce(0, +) / Double(metrics.count)
        let avgDiskPercent = metrics.map { ($0.diskUsedGB / $0.diskTotalGB) * 100 }.reduce(0, +) / Double(metrics.count)
        
        // Calculate score from averages
        var penalty = 0
        
        // Memory penalty
        if avgMemoryPercent > Thresholds.memoryCritical { penalty += 40 }
        else if avgMemoryPercent > Thresholds.memoryHigh { penalty += 25 }
        else if avgMemoryPercent > Thresholds.memoryModerate { penalty += 10 }
        
        // Swap penalty
        if avgSwapGB > Thresholds.swapCritical { penalty += 20 }
        else if avgSwapGB > Thresholds.swapHigh { penalty += 15 }
        else if avgSwapGB > Thresholds.swapModerate { penalty += 8 }
        
        // CPU penalty
        if avgCPUPercent > Thresholds.cpuCritical { penalty += 20 }
        else if avgCPUPercent > Thresholds.cpuHigh { penalty += 10 }
        
        // Disk penalty
        if avgDiskPercent > Thresholds.diskCritical { penalty += 15 }
        else if avgDiskPercent > Thresholds.diskHigh { penalty += 10 }
        
        return max(0, 100 - penalty)
    }
    
    /// Calculate average health score over a period
    private func calculateAverageScore(hours: Int) -> Double? {
        let cutoffDate = Date().addingTimeInterval(-Double(hours) * 3600)
        let metrics = historicalService.metrics.filter { $0.timestamp >= cutoffDate }
        guard !metrics.isEmpty else { return nil }

        let scores = metrics.map { metric -> Int in
            var penalty = 0

            if metric.memoryUsedPercent > Thresholds.memoryCritical { penalty += 40 }
            else if metric.memoryUsedPercent > Thresholds.memoryHigh { penalty += 25 }
            else if metric.memoryUsedPercent > Thresholds.memoryModerate { penalty += 10 }

            if metric.swapUsedGB > Thresholds.swapCritical { penalty += 20 }
            else if metric.swapUsedGB > Thresholds.swapHigh { penalty += 15 }
            else if metric.swapUsedGB > Thresholds.swapModerate { penalty += 8 }

            if metric.cpuUsagePercent > Thresholds.cpuCritical { penalty += 20 }
            else if metric.cpuUsagePercent > Thresholds.cpuHigh { penalty += 10 }

            let diskPercent = (metric.diskUsedGB / metric.diskTotalGB) * 100
            if diskPercent > Thresholds.diskCritical { penalty += 15 }
            else if diskPercent > Thresholds.diskHigh { penalty += 10 }

            return max(0, 100 - penalty)
        }

        return scores.reduce(0.0, { $0 + Double($1) }) / Double(scores.count)
    }
    
    /// Get grade for a score
    private func gradeForScore(_ score: Int) -> HealthGrade {
        switch score {
        case 90...100: return .a
        case 80..<90: return .b
        case 70..<80: return .c
        case 50..<70: return .d
        default: return .f
        }
    }

    /// Get trend description
    private func trendDescription(_ trend: HealthTrend) -> String? {
        switch trend {
        case .improving: return "Health is improving."
        case .declining: return "Health is declining."
        case .stable: return nil  // Don't mention stable
        case .insufficientData: return nil  // Don't mention insufficient data
        }
    }
}
