import Foundation
import SystemConfiguration

/// Monitors network throughput and battery/thermal state
class SystemHealthMonitor: ObservableObject {
    static let shared = SystemHealthMonitor()

    // Network
    @Published var downloadSpeed: Double = 0 // MB/s
    @Published var uploadSpeed: Double = 0   // MB/s
    @Published var totalDownloadGB: Double = 0
    @Published var totalUploadGB: Double = 0
    @Published var networkHistory: [NetworkEntry] = []

    // Battery
    @Published var batteryPercentage: Double = 100
    @Published var isCharging: Bool = false
    @Published var timeRemaining: String = "N/A"
    @Published var cycleCount: Int = 0
    @Published var batteryHealth: String = "Unknown"

    // Thermal
    @Published var thermalState: String = "Nominal"

    struct NetworkEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let downloadMB: Double
        let uploadMB: Double
    }

    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTimestamp: Date = Date()

    private init() {}

    // MARK: - Update All

    func update() {
        updateNetwork()
        updateBattery()
        updateThermal()
    }

    // MARK: - Network

    private func updateNetwork() {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0 else { return }
        defer { freeifaddrs(ifaddrs) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0

        var ptr = ifaddrs
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            let addr = ptr!.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: ptr!.pointee.ifa_name)
            // Skip loopback
            guard name.hasPrefix("en") || name.hasPrefix("utun") else { continue }

            let data = ptr!.pointee.ifa_data
            let networkData = data?.assumingMemoryBound(to: if_data.self)
            if let data = networkData {
                bytesIn += UInt64(data.pointee.ifi_ibytes)
                bytesOut += UInt64(data.pointee.ifi_obytes)
            }
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(previousTimestamp)

        if previousBytesIn > 0 && elapsed > 0 {
            let dlSpeed = Double(bytesIn - previousBytesIn) / elapsed / (1024 * 1024)
            let ulSpeed = Double(bytesOut - previousBytesOut) / elapsed / (1024 * 1024)

            DispatchQueue.main.async {
                self.downloadSpeed = max(0, dlSpeed)
                self.uploadSpeed = max(0, ulSpeed)
                self.totalDownloadGB = Double(bytesIn) / (1024 * 1024 * 1024)
                self.totalUploadGB = Double(bytesOut) / (1024 * 1024 * 1024)

                let entry = NetworkEntry(timestamp: now, downloadMB: self.downloadSpeed, uploadMB: self.uploadSpeed)
                self.networkHistory.append(entry)
                if self.networkHistory.count > 300 {
                    self.networkHistory.removeFirst(self.networkHistory.count - 300)
                }
            }
        }

        previousBytesIn = bytesIn
        previousBytesOut = bytesOut
        previousTimestamp = now
    }

    // MARK: - Battery (via pmset)

    private func updateBattery() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            // Parse battery percentage: "75%;"
            if let pctMatch = output.range(of: #"(\d+)%;?"#, options: .regularExpression) {
                let pctStr = output[pctMatch].filter { $0.isNumber }
                if let pct = Double(pctStr) {
                    DispatchQueue.main.async {
                        self.batteryPercentage = pct
                    }
                }
            }

            // Parse charging state
            let charging = output.contains("AC Power") || output.contains("charging")
            DispatchQueue.main.async {
                self.isCharging = charging
            }

            // Parse time remaining: "3:45 remaining" or "2:30 until charged"
            if let timeMatch = output.range(of: #"(\d+:\d+)\s*(remaining|until charged)"#, options: .regularExpression) {
                let timeStr = String(output[timeMatch])
                if let timeRange = timeStr.range(of: #"\d+:\d+"#, options: .regularExpression) {
                    let timeValue = String(timeStr[timeRange])
                    let parts = timeValue.split(separator: ":")
                    if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                        DispatchQueue.main.async {
                            if timeStr.contains("until charged") {
                                self.timeRemaining = "\(h)h \(m)m to full"
                            } else {
                                self.timeRemaining = "\(h)h \(m)m"
                            }
                        }
                    }
                }
            } else if output.contains("AC Power") && !output.contains("charging") {
                DispatchQueue.main.async {
                    self.timeRemaining = "Fully Charged"
                }
            }

            // Get cycle count via ioreg (simpler parsing)
            let cycleTask = Process()
            cycleTask.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
            cycleTask.arguments = ["-l", "-w0", "-p", "IOService"]
            let cyclePipe = Pipe()
            cycleTask.standardOutput = cyclePipe

            do {
                try cycleTask.run()
                cycleTask.waitUntilExit()
                let cycleData = cyclePipe.fileHandleForReading.readDataToEndOfFile()
                if let cycleOutput = String(data: cycleData, encoding: .utf8),
                   let cycleMatch = cycleOutput.range(of: #""CycleCount"\s*=\s*(\d+)"#, options: .regularExpression) {
                    let numStr = cycleOutput[cycleMatch].filter { $0.isNumber }
                    if let count = Int(numStr) {
                        DispatchQueue.main.async {
                            self.cycleCount = count
                            if count < 500 {
                                self.batteryHealth = "Excellent"
                            } else if count < 800 {
                                self.batteryHealth = "Good"
                            } else if count < 1000 {
                                self.batteryHealth = "Fair"
                            } else {
                                self.batteryHealth = "Service Soon"
                            }
                        }
                    }
                }
            } catch {
                // Cycle count unavailable on desktop Macs
                DispatchQueue.main.async {
                    self.batteryHealth = "N/A"
                }
            }
        } catch {
            // No battery (desktop Mac)
            DispatchQueue.main.async {
                self.batteryPercentage = 100
                self.isCharging = true
                self.timeRemaining = "AC Power"
                self.batteryHealth = "N/A"
            }
        }
    }

    // MARK: - Thermal

    private func updateThermal() {
        let thermal = ProcessInfo.processInfo.thermalState
        DispatchQueue.main.async {
            switch thermal {
            case .nominal:
                self.thermalState = "Nominal"
            case .fair:
                self.thermalState = "Fair"
            case .serious:
                self.thermalState = "Serious"
            case .critical:
                self.thermalState = "Critical"
            @unknown default:
                self.thermalState = "Unknown"
            }
        }
    }

    // MARK: - Connection Info

    var isConnectedViaWiFi: Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") else { return false }
        var flags = SCNetworkReachabilityFlags()
        SCNetworkReachabilityGetFlags(reachability, &flags)
        return flags.contains(.reachable)
    }
}
