//
//  TemperatureMonitor.swift
//  Pulse
//
//  Temperature monitoring using IOKit and SMC (System Management Controller)
//  Works on both Intel and Apple Silicon Macs without requiring root/sudo
//

import Foundation
import IOKit
import IOKit.ps
import Combine
import SwiftUI

// MARK: - SMC Constants

private let KERNEL_INDEX_SMC: UInt32 = 2
private let SMC_CMD_READ_KEYINFO: UInt8 = 9
private let SMC_CMD_READ_BYTES: UInt8 = 5

// MARK: - SMC Data Structures

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers: SMCVersion = SMCVersion()
    var pLimitData: SMCPLimitData = SMCPLimitData()
    var keyInfo: SMCKeyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    
    static var size: Int { MemoryLayout<SMCKeyData>.size }
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

// MARK: - SMC Connection Helper

private class SMCConnection {
    private var connection: io_connect_t = 0
    private var service: io_object_t = 0
    private var isConnected = false
    
    enum SMCError: Error, LocalizedError {
        case connectionFailed(String)
        case serviceNotFound
        case readFailed(String)
        case invalidKey
        case notConnected
        
        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "SMC connection failed: \(msg)"
            case .serviceNotFound: return "AppleSMC service not found"
            case .readFailed(let msg): return "SMC read failed: \(msg)"
            case .invalidKey: return "Invalid SMC key"
            case .notConnected: return "SMC not connected"
            }
        }
    }
    
    func open() throws {
        var masterPort: mach_port_t = 0
        #if compiler(>=5.5)
        let kr = IOMainPort(0, &masterPort)
        #else
        let kr = IOMasterPort(0, &masterPort)
        #endif
        guard kr == KERN_SUCCESS else {
            throw SMCError.connectionFailed("IOMainPort failed: \(kr)")
        }
        
        guard let matching = IOServiceMatching("AppleSMC") else {
            throw SMCError.connectionFailed("IOServiceMatching returned nil")
        }
        
        var iterator: io_iterator_t = 0
        let kr2 = IOServiceGetMatchingServices(masterPort, matching, &iterator)
        guard kr2 == KERN_SUCCESS else {
            throw SMCError.connectionFailed("IOServiceGetMatchingServices failed: \(kr2)")
        }
        
        service = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        
        guard service != 0 else {
            throw SMCError.serviceNotFound
        }
        
        let kr3 = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard kr3 == KERN_SUCCESS else {
            IOObjectRelease(service)
            throw SMCError.connectionFailed("IOServiceOpen failed: \(kr3)")
        }
        
        isConnected = true
    }
    
    func close() {
        guard isConnected else { return }
        
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
        if service != 0 {
            IOObjectRelease(service)
            service = 0
        }
        isConnected = false
    }
    
    deinit {
        close()
    }
    
    func readKey(_ key: String) throws -> Double {
        guard isConnected else { throw SMCError.notConnected }
        guard key.count == 4 else { throw SMCError.invalidKey }
        
        let keyCode = fourCharCode(from: key)
        
        // Read key info first
        let keyInfo = try readKeyInfo(keyCode)
        let dataType = dataTypeString(keyInfo.dataType)
        
        // Read bytes
        let bytes = try readKeyBytes(keyCode, keyInfo)
        
        // Parse based on data type
        return parseBytes(bytes, dataType: dataType, dataSize: Int(keyInfo.dataSize))
    }
    
    private func readKeyInfo(_ key: UInt32) throws -> SMCKeyInfo {
        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = key
        input.data8 = SMC_CMD_READ_KEYINFO

        let inputSize: Int = SMCKeyData.size
        var outputSize: Int = SMCKeyData.size

        let kr = withUnsafeMutablePointer(to: &input) { inputPtr in
            withUnsafeMutablePointer(to: &output) { outputPtr in
                IOConnectCallStructMethod(
                    connection,
                    KERNEL_INDEX_SMC,
                    inputPtr,
                    inputSize,
                    outputPtr,
                    &outputSize
                )
            }
        }
        guard kr == KERN_SUCCESS else {
            throw SMCError.readFailed("Read key info failed: \(kr)")
        }

        return output.keyInfo
    }

    private func readKeyBytes(_ key: UInt32, _ keyInfo: SMCKeyInfo) throws -> [UInt8] {
        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = key
        input.data8 = SMC_CMD_READ_BYTES
        input.keyInfo = keyInfo

        let inputSize: Int = SMCKeyData.size
        var outputSize: Int = SMCKeyData.size
        
        let kr = withUnsafeMutablePointer(to: &input) { inputPtr in
            withUnsafeMutablePointer(to: &output) { outputPtr in
                IOConnectCallStructMethod(
                    connection,
                    KERNEL_INDEX_SMC,
                    inputPtr,
                    inputSize,
                    outputPtr,
                    &outputSize
                )
            }
        }
        guard kr == KERN_SUCCESS else {
            throw SMCError.readFailed("Read bytes failed: \(kr)")
        }
        
        let size = Int(keyInfo.dataSize)
        return withUnsafeBytes(of: output.bytes) { ptr in
            Array(ptr.prefix(size))
        }
    }
    
    private func parseBytes(_ bytes: [UInt8], dataType: String, dataSize: Int) -> Double {
        let dataTypeStr = dataType.trimmingCharacters(in: .whitespaces).padding(toLength: 4, withPad: " ", startingAt: 0)
        
        // sp78, sp87, sp96 - signed fixed point (most temperature sensors)
        if dataTypeStr.hasPrefix("sp") {
            guard bytes.count >= 2 else { return 0 }
            let raw = Int16(Int8(bitPattern: bytes[0])) << 8 | Int16(bytes[1])
            return Double(raw) / 256.0
        }
        
        // fp88, fp79 - unsigned fixed point
        if dataTypeStr.hasPrefix("fp") {
            guard bytes.count >= 2 else { return 0 }
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 256.0
        }
        
        switch dataTypeStr {
        case "flt ":
            guard bytes.count >= 4 else { return 0 }
            // Float from 4 bytes (big-endian)
            let floatValue = bytes.withUnsafeBytes { ptr -> Float in
                guard ptr.count >= 4 else { return 0.0 }
                return ptr.load(as: Float.self)
            }
            return Double(floatValue)
        case "ui8 ":
            return Double(bytes[0])
        case "ui16":
            guard bytes.count >= 2 else { return 0 }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return 0 }
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        default:
            return 0
        }
    }
    
    private func fourCharCode(from string: String) -> UInt32 {
        guard string.count == 4 else { return 0 }
        let chars = string.utf8CString
        return UInt32(chars[0]) << 24 | UInt32(chars[1]) << 16 | UInt32(chars[2]) << 8 | UInt32(chars[3])
    }
    
    private func dataTypeString(_ type: UInt32) -> String {
        let bytes = [
            UInt8(type >> 24 & 0xFF),
            UInt8(type >> 16 & 0xFF),
            UInt8(type >> 8 & 0xFF),
            UInt8(type & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }
}

// MARK: - Temperature Data Model

struct TemperatureReading: Identifiable {
    let id = UUID()
    let name: String
    let key: String
    let value: Double
    let category: TemperatureCategory
    
    enum TemperatureCategory {
        case cpu
        case gpu
        case battery
        case ambient
        case memory
        case palmRest
        case wifi
        case unknown
        
        var icon: String {
            switch self {
            case .cpu: return "cpu"
            case .gpu: return "gpu"
            case .battery: return "battery.100"
            case .ambient: return "thermometer.medium"
            case .memory: return "memorychip"
            case .palmRest: return "hand.raised"
            case .wifi: return "wifi"
            case .unknown: return "thermometer"
            }
        }
        
        var displayName: String {
            switch self {
            case .cpu: return "CPU"
            case .gpu: return "GPU"
            case .battery: return "Battery"
            case .ambient: return "Ambient"
            case .memory: return "Memory"
            case .palmRest: return "Palm Rest"
            case .wifi: return "WiFi"
            case .unknown: return "Sensor"
            }
        }
    }
    
    var thermalState: ThermalState {
        switch value {
        case 0..<50: return .cool
        case 50..<70: return .warm
        case 70..<85: return .hot
        default: return .critical
        }
    }
    
    enum ThermalState {
        case cool, warm, hot, critical
        
        var color: Color {
            switch self {
            case .cool: return .green
            case .warm: return .yellow
            case .hot: return .orange
            case .critical: return .red
            }
        }
        
        var description: String {
            switch self {
            case .cool: return "Cool"
            case .warm: return "Warm"
            case .hot: return "Hot"
            case .critical: return "Critical"
            }
        }
    }
}

import SwiftUI

// MARK: - Temperature Monitor Service

/// Real-time temperature monitoring using SMC (Intel) and Power Management (Apple Silicon)
/// 
/// Limitations:
/// - Intel Macs: Uses SMC via IOKit - generally reliable
/// - Apple Silicon (M1/M2/M3): SMC keys may not exist or return invalid data
/// - Some sensors may return 0°C on certain Mac models
/// 
/// For accurate temperature readings on Apple Silicon, consider using:
/// - iStat Menus
/// - Stats app (github.com/exelban/stats)
/// - PowerMetrics (command line: sudo powermetrics)
class TemperatureMonitor: ObservableObject {
    static let shared = TemperatureMonitor()
    
    // MARK: - Published Properties
    
    @Published var cpuTemperature: Double = 0
    @Published var gpuTemperature: Double = 0
    @Published var batteryTemperature: Double = 0
    @Published var ambientTemperature: Double = 0
    @Published var memoryTemperature: Double = 0
    @Published var allSensors: [TemperatureReading] = []
    @Published var isMonitoring: Bool = false
    @Published var lastError: String?
    @Published var lastUpdated: Date?
    
    // MARK: - Computed Properties
    
    /// Maximum temperature across all sensors
    var maxTemperature: Double {
        max(cpuTemperature, gpuTemperature, memoryTemperature)
    }
    
    /// Overall thermal state
    var overallThermalState: TemperatureReading.ThermalState {
        let max = maxTemperature
        switch max {
        case 0..<50: return .cool
        case 50..<70: return .warm
        case 70..<85: return .hot
        default: return .critical
        }
    }
    
    /// Is this an Apple Silicon Mac?
    var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    /// CPU architecture description
    var cpuArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel"
        #endif
    }
    
    // MARK: - Private Properties
    
    private let smc = SMCConnection()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // SMC keys to try (in order of preference) for each sensor type
    private let cpuKeys = ["TC0P", "TC0D", "TC0H", "TCXC", "TC0E", "TC0F", "TCAD"]
    private let gpuKeys = ["TG0P", "TG0D", "TCgc", "TGDD"]
    private let batteryKeys = ["TB0T", "TB1T", "TB2T", "TB3T"]
    private let ambientKeys = ["TA0P", "TA1P"]
    private let memoryKeys = ["TM0P", "TM0S", "TM1P"]
    private let palmRestKeys = ["TS0P", "TS1P"]
    private let wifiKeys = ["Tw0P"]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start monitoring temperatures at specified interval
    func startMonitoring(interval: TimeInterval = 2.0) {
        guard !isMonitoring else { return }
        
        do {
            try smc.open()
            isMonitoring = true
            lastError = nil
            
            // Initial read
            update()
            
            // Start timer for periodic updates
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.update()
            }
            
            print("[TemperatureMonitor] Started monitoring (interval: \(interval)s)")
        } catch {
            lastError = error.localizedDescription
            print("[TemperatureMonitor] Failed to start: \(error)")
            // Gracefully handle case where SMC access is not available
            isMonitoring = true
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        smc.close()
        isMonitoring = false
        print("[TemperatureMonitor] Stopped monitoring")
    }
    
    /// Force immediate update
    func refresh() {
        update()
    }
    
    // MARK: - Private Methods
    
    private func update() {
        // Read all sensor types
        let cpu = readFirstAvailable(keys: cpuKeys)
        let gpu = readFirstAvailable(keys: gpuKeys)
        let battery = readFirstAvailable(keys: batteryKeys)
        let ambient = readFirstAvailable(keys: ambientKeys)
        let memory = readFirstAvailable(keys: memoryKeys)
        let palmRest = readFirstAvailable(keys: palmRestKeys)
        let wifi = readFirstAvailable(keys: wifiKeys)
        
        // Update published properties on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cpuTemperature = cpu
            self.gpuTemperature = gpu
            self.batteryTemperature = battery
            self.ambientTemperature = ambient
            self.memoryTemperature = memory
            self.lastUpdated = Date()
            
            // Build sensor list
            self.allSensors = self.buildSensorList(
                cpu: cpu, gpu: gpu, battery: battery,
                ambient: ambient, memory: memory, palmRest: palmRest, wifi: wifi
            )
        }
    }
    
    private func readFirstAvailable(keys: [String]) -> Double {
        for key in keys {
            do {
                let value = try smc.readKey(key)
                // Sanity check: temperature should be between 0 and 150°C
                if value > 0 && value < 150 {
                    return value
                }
            } catch {
                continue
            }
        }
        return 0
    }
    
    private func buildSensorList(
        cpu: Double, gpu: Double, battery: Double,
        ambient: Double, memory: Double, palmRest: Double, wifi: Double
    ) -> [TemperatureReading] {
        var sensors: [TemperatureReading] = []
        
        // Add sensors that have valid readings (> 0°C) to the list;
        // Some sensors might not be available on all Macs
        if cpu > 0 {
            sensors.append(TemperatureReading(name: "CPU", key: "CPU", value: cpu, category: .cpu))
        }
        if gpu > 0 {
            sensors.append(TemperatureReading(name: "GPU", key: "GPU", value: gpu, category: .gpu))
        }
        if memory > 0 {
            sensors.append(TemperatureReading(name: "Memory", key: "MEM", value: memory, category: .memory))
        }
        if battery > 0 {
            sensors.append(TemperatureReading(name: "Battery", key: "BAT", value: battery, category: .battery))
        }
        if ambient > 0 {
            sensors.append(TemperatureReading(name: "Ambient", key: "AMB", value: ambient, category: .ambient))
        }
        if palmRest > 0 {
            sensors.append(TemperatureReading(name: "Palm Rest", key: "PALM", value: palmRest, category: .palmRest))
        }
        if wifi > 0 {
            sensors.append(TemperatureReading(name: "WiFi", key: "WIFI", value: wifi, category: .wifi))
        }
        
        return sensors.sorted { $0.value > $1.value }
    }
    
    // MARK: - Debug Methods
    
    /// Read a specific SMC key
    func readKey(_ key: String) -> Double? {
        do {
            return try smc.readKey(key)
        } catch {
            return nil
        }
    }
    
    /// Get all known temperature keys
    var knownKeys: [String] {
        cpuKeys + gpuKeys + batteryKeys + ambientKeys + memoryKeys + palmRestKeys + wifiKeys
    }
}

// MARK: - SwiftUI Color Extension

import SwiftUI

extension Color {
    /// Temperature-based color gradient
    static func temperature(_ celsius: Double) -> Color {
        switch celsius {
        case 0..<40:
            return Color(red: 0.3, green: 0.8, blue: 0.5)  // Cool green
        case 40..<50:
            return Color(red: 0.5, green: 0.85, blue: 0.4)  // Light green
        case 50..<60:
            return Color(red: 0.85, green: 0.85, blue: 0.2)  // Yellow-green
        case 60..<70:
            return Color(red: 1.0, green: 0.8, blue: 0.0)  // Yellow
        case 70..<80:
            return Color(red: 1.0, green: 0.5, blue: 0.0)  // Orange
        case 80..<90:
            return Color(red: 1.0, green: 0.25, blue: 0.0)  // Dark orange
        default:
            return Color(red: 1.0, green: 0.0, blue: 0.0)  // Red
        }
    }
    
    /// Temperature gradient for gauges
    static var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [
                .green,      // Cool
                .yellow,     // Warm
                .orange,     // Hot
                .red         // Critical
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}