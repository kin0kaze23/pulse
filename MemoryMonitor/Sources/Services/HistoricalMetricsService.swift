//
//  HistoricalMetricsService.swift
//  Pulse
//
//  Records historical system metrics for chart visualization
//  Memory, temperature, CPU, disk, network usage over time
//

import Foundation
import Combine

// MARK: - Historical Metrics Model

struct MetricPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // Memory metrics
    let memoryUsedGB: Double
    let memoryTotalGB: Double
    let swapUsedGB: Double
    
    // CPU metrics
    let cpuUsagePercent: Double
    let coreCount: Int
    
    // Temperature
    let temperatureCPU: Double?
    let temperatureGPU: Double?
    
    // Disk metrics
    let diskUsedGB: Double
    let diskTotalGB: Double
    let networkThroughput: (upload: Double, download: Double)? // Mbps
    
    var memoryUsedPercent: Double {
        guard memoryTotalGB > 0 else { return 0 }
        return (memoryUsedGB / memoryTotalGB) * 100.0
    }
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        memoryUsedGB: Double,
        memoryTotalGB: Double,
        swapUsedGB: Double,
        cpuUsagePercent: Double,
        coreCount: Int,
        temperatureCPU: Double? = nil,
        temperatureGPU: Double? = nil,
        diskUsedGB: Double,
        diskTotalGB: Double,
        networkThroughput: (Double, Double)? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.memoryUsedGB = memoryUsedGB
        self.memoryTotalGB = memoryTotalGB
        self.swapUsedGB = swapUsedGB
        self.cpuUsagePercent = cpuUsagePercent
        self.coreCount = coreCount
        self.temperatureCPU = temperatureCPU
        self.temperatureGPU = temperatureGPU
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.networkThroughput = networkThroughput
    }
    
    // Custom Codable implementation to handle tuple for networkThroughput
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, memoryUsedGB, memoryTotalGB, swapUsedGB, 
             cpuUsagePercent, coreCount, temperatureCPU, temperatureGPU,
             diskUsedGB, diskTotalGB, networkThroughput, networkUpload, networkDownload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        memoryUsedGB = try container.decode(Double.self, forKey: .memoryUsedGB)
        memoryTotalGB = try container.decode(Double.self, forKey: .memoryTotalGB)
        swapUsedGB = try container.decode(Double.self, forKey: .swapUsedGB)
        cpuUsagePercent = try container.decode(Double.self, forKey: .cpuUsagePercent)
        coreCount = try container.decode(Int.self, forKey: .coreCount)
        temperatureCPU = try container.decodeIfPresent(Double.self, forKey: .temperatureCPU)
        temperatureGPU = try container.decodeIfPresent(Double.self, forKey: .temperatureGPU)
        diskUsedGB = try container.decode(Double.self, forKey: .diskUsedGB)
        diskTotalGB = try container.decode(Double.self, forKey: .diskTotalGB)
        
        // Handle custom network throughput tuple
        let upload = try? container.decodeIfPresent(Double.self, forKey: .networkUpload)
        let download = try? container.decodeIfPresent(Double.self, forKey: .networkDownload)
        if let uploadVal = upload, let downloadVal = download {
            networkThroughput = (uploadVal, downloadVal)
        } else {
            networkThroughput = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(memoryUsedGB, forKey: .memoryUsedGB)
        try container.encode(memoryTotalGB, forKey: .memoryTotalGB)
        try container.encode(swapUsedGB, forKey: .swapUsedGB)
        try container.encode(cpuUsagePercent, forKey: .cpuUsagePercent)
        try container.encode(coreCount, forKey: .coreCount)
        try container.encodeIfPresent(temperatureCPU, forKey: .temperatureCPU)
        try container.encodeIfPresent(temperatureGPU, forKey: .temperatureGPU)
        try container.encode(diskUsedGB, forKey: .diskUsedGB)
        try container.encode(diskTotalGB, forKey: .diskTotalGB)
        
        // Handle custom network throughput tuple
        if let throughput = networkThroughput {
            try container.encodeIfPresent(throughput.upload, forKey: .networkUpload)
            try container.encodeIfPresent(throughput.download, forKey: .networkDownload)
        }
    }
}

// MARK: - Historical Metrics Service

/// Collects and stores historical system metrics for chart visualization
class HistoricalMetricsService: ObservableObject {
    static let shared = HistoricalMetricsService()
    
    @Published var metrics: [MetricPoint] = []
    @Published var isRecording = false
    @Published var recordingInterval: TimeInterval = 30 // 30 seconds by default
    @Published var retentionDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private var timer: Timer?
    private let workQueue = DispatchQueue(label: "com.pulse.historicalmetrics", qos: .background)
    private let maxPoints: Int = 10080 // About 1 week at 30 sec intervals
    
    private var memoryMonitor: SystemMemoryMonitor?
    private var cpuMonitor: CPUMonitor?
    private var temperatureMonitor: TemperatureMonitor?
    private var diskMonitor: DiskMonitor?
    
    private let fileManager = FileManager.default
    private let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    private lazy var historyFilePath: URL = {
        // Ensure Application Support directory exists
        do {
            try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        } catch {
            print("[HistoricalMetricsService] Could not create app support directory: \(error)")
        }
        
        // Create app-specific subdirectory
        let appDir = appSupportDirectory.appendingPathComponent("Pulse")
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            print("[HistoricalMetricsService] Could not create Pulse subdirectory: \(error)")
        }
        
        return appDir.appendingPathComponent("pulse_metrics.json")
    }()
    
    private init() {
        loadSavedHistory()
        setupMonitors()
    }
    
    deinit {
        // Make sure timer is stopped on deinit
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Setup
    
    private func setupMonitors() {
        // Connect to existing monitors
        memoryMonitor = SystemMemoryMonitor.shared
        cpuMonitor = CPUMonitor.shared
        temperatureMonitor = TemperatureMonitor.shared
        diskMonitor = DiskMonitor.shared
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        
        // Record initial data point
        recordCurrentMetrics()
        
        // Start regular recording
        timer = Timer.scheduledTimer(withTimeInterval: recordingInterval, repeats: true) { [weak self] _ in
            self?.recordCurrentMetrics()
        }
    }
    
    func stopRecording() {
        timer?.invalidate()
        timer = nil
        isRecording = false
    }
    
    func changeRecordingInterval(_ newInterval: TimeInterval) {
        recordingInterval = max(newInterval, 1.0) // Minimum 1 second
        if isRecording {
            stopRecording()
            startRecording()
        }
    }
    
    // MARK: - Data Collection
    
    private func recordCurrentMetrics() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = Date()
            
            // Collect current metric values
            let currentMemory = self.getCurrentMemoryUsage()
            let cpuUsage = self.getCurrentCPUUsage()
            let temperature = self.getCurrentTemperatures()
            let diskInfo = self.getCurrentDiskUsage()
            
            let point = MetricPoint(
                timestamp: timestamp,
                memoryUsedGB: currentMemory.usedGB,
                memoryTotalGB: currentMemory.totalGB,
                swapUsedGB: currentMemory.swapUsedGB,
                cpuUsagePercent: cpuUsage,
                coreCount: self.getCoreCount(),
                temperatureCPU: temperature.0,
                temperatureGPU: temperature.1,
                diskUsedGB: diskInfo.usedGB,
                diskTotalGB: diskInfo.totalGB
            )
            
            // All @Published property updates must be on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.metrics.append(point)
                
                // Limit the amount of historical data to prevent memory issues
                if self.metrics.count > self.maxPoints {
                    self.metrics = Array(self.metrics.suffix(self.maxPoints))
                }
                
                // Remove old metrics based on duration
                let cutoffDate = Date().addingTimeInterval(-self.retentionDuration)
                self.metrics.removeAll { $0.timestamp < cutoffDate }
                
                // Save to disk periodically
                if self.metrics.count % 10 == 0 {
                    self.saveHistory()
                }
            }
        }
    }
    
    private func getCurrentMemoryUsage() -> (usedGB: Double, totalGB: Double, swapUsedGB: Double) {
        guard let currentMemory = memoryMonitor?.currentMemory else {
            return (0, 0, 0)
        }
        
        return (currentMemory.usedGB, currentMemory.totalGB, currentMemory.swapUsedGB)
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Include both user and system CPU usage for accurate total
        let userCPU = cpuMonitor?.userCPUPercentage ?? 0
        let systemCPU = cpuMonitor?.systemCPUPercentage ?? 0
        return userCPU + systemCPU
    }
    
    private func getCurrentTemperatures() -> (cpu: Double?, gpu: Double?) {
        let cpuTemp = temperatureMonitor?.cpuTemperature ?? 0.0
        let gpuTemp = temperatureMonitor?.gpuTemperature ?? 0.0
        
        return (cpuTemp > 0 ? cpuTemp : nil, gpuTemp > 0 ? gpuTemp : nil)
    }
    
    private func getCurrentDiskUsage() -> (usedGB: Double, totalGB: Double) {
        let primaryDisk = diskMonitor?.primaryDisk
        return (
            primaryDisk?.usedGB ?? 0,
            primaryDisk?.totalGB ?? 1
        )
    }
    
    private func getCoreCount() -> Int {
        return ProcessInfo.processInfo.processorCount
    }
    
    // MARK: - Data Management
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(metrics)
            try data.write(to: historyFilePath)
        } catch {
            print("[HistoricalMetricsService] Failed to save history: \(error)")
        }
    }
    
    private func loadSavedHistory() {
        do {
            if fileManager.fileExists(atPath: historyFilePath.path) {
                let data = try Data(contentsOf: historyFilePath)
                metrics = try JSONDecoder().decode([MetricPoint].self, from: data)
                print("[HistoricalMetricsService] Loaded \(metrics.count) historical points from \(historyFilePath.path)")
            }
        } catch {
            print("[HistoricalMetricsService] Failed to load history from \(historyFilePath.path), starting fresh: \(error)")
            metrics = []
        }
    }
    
    func clearHistory() {
        metrics.removeAll()
        saveHistory()
    }
    
    // MARK: - Chart Data Helpers
    
    /// Get metrics filtered by time range
    func getMetrics(for timeRange: TimeRange) -> [MetricPoint] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.seconds)
        return metrics.filter { $0.timestamp >= cutoffDate }.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get memory usage trend
    func getMemoryTrend(for timeRange: TimeRange, samplingRate: Int = 1) -> [MetricPoint] {
        let allMetrics = getMetrics(for: timeRange)
        return Array(allMetrics.suffix(max(1, allMetrics.count / samplingRate)))
    }
    
    /// Calculate average values for a range
    func getAverageMemoryUsage(for timeRange: TimeRange) -> (usedGB: Double, usedPercent: Double) {
        let filteredMetrics = getMetrics(for: timeRange)
        guard !filteredMetrics.isEmpty else { return (0, 0) }
        
        let avgUsedGB = filteredMetrics.reduce(0) { sum, point in sum + point.memoryUsedGB } / Double(filteredMetrics.count)
        let avgPercent = filteredMetrics.reduce(0) { sum, point in sum + point.memoryUsedPercent } / Double(filteredMetrics.count)
        
        return (avgUsedGB, avgPercent)
    }
    
    func getAverageCPUUsage(for timeRange: TimeRange) -> Double {
        let filteredMetrics = getMetrics(for: timeRange)
        guard !filteredMetrics.isEmpty else { return 0 }
        
        return filteredMetrics.reduce(0) { sum, point in sum + point.cpuUsagePercent } / Double(filteredMetrics.count)
    }
}

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable {
    case last1Hour = "Past Hour"
    case last6Hours = "Past 6 Hours"
    case last24Hours = "Today"
    case lastWeek = "Past Week"
    
    var seconds: TimeInterval {
        switch self {
        case .last1Hour: return 1 * 60 * 60
        case .last6Hours: return 6 * 60 * 60
        case .last24Hours: return 24 * 60 * 60
        case .lastWeek: return 7 * 24 * 60 * 60
        }
    }
    
    var label: String {
        switch self {
        case .last1Hour: return "Past Hour"
        case .last6Hours: return "Past 6 Hours"
        case .last24Hours: return "Today"
        case .lastWeek: return "Past Week"
        }
    }
}