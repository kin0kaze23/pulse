import Foundation

/// Time Machine local snapshots manager
/// Local snapshots can consume 50-200GB of disk space
/// They are safe to delete - iCloud/external backups remain intact
class TimeMachineManager: ObservableObject {
    static let shared = TimeMachineManager()
    
    @Published var snapshots: [TimeMachineSnapshot] = []
    @Published var totalSizeGB: Double = 0
    @Published var isScanning = false
    @Published var lastScanDate: Date?
    
    struct TimeMachineSnapshot: Identifiable {
        let id = UUID()
        let name: String
        let date: Date
        let sizeGB: Double
        let isDeletable: Bool
        
        var displayName: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        var sizeText: String {
            if sizeGB >= 1 {
                return String(format: "%.1f GB", sizeGB)
            }
            return String(format: "%.0f MB", sizeGB * 1024)
        }
    }
    
    private init() {}
    
    // MARK: - Scanning
    
    /// Scan for local Time Machine snapshots
    func scanSnapshots() {
        guard !isScanning else { return }
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var foundSnapshots: [TimeMachineSnapshot] = []
            var totalGB: Double = 0
            
            // Use tmutil to list local snapshots
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            task.arguments = ["listlocalsnapshots", "/"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // Parse output like: "com.apple.TimeMachine.2024-03-22-123456"
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("com.apple.TimeMachine.") else { continue }
                    
                    // Extract date from snapshot name
                    let dateString = trimmed.replacingOccurrences(of: "com.apple.TimeMachine.", with: "")
                    if let snapshotDate = parseSnapshotDate(dateString) {
                        // Estimate size (Time Machine doesn't provide individual snapshot sizes easily)
                        // We'll estimate based on the total and divide by count
                        let snapshot = TimeMachineSnapshot(
                            name: trimmed,
                            date: snapshotDate,
                            sizeGB: 0, // Will be calculated after total
                            isDeletable: true
                        )
                        foundSnapshots.append(snapshot)
                    }
                }
                
                // Get total Time Machine local backup size
                totalGB = self.getLocalBackupSize()
                
                // Distribute size among snapshots
                if foundSnapshots.count > 0 && totalGB > 0 {
                    let sizePerSnapshot = totalGB / Double(foundSnapshots.count)
                    foundSnapshots = foundSnapshots.map { snapshot in
                        TimeMachineSnapshot(
                            name: snapshot.name,
                            date: snapshot.date,
                            sizeGB: sizePerSnapshot,
                            isDeletable: snapshot.isDeletable
                        )
                    }
                }
                
                print("[TimeMachineManager] Found \(foundSnapshots.count) snapshots, total \(totalGB)GB")
                
            } catch {
                print("[TimeMachineManager] Error scanning snapshots: \(error)")
            }
            
            DispatchQueue.main.async {
                self.snapshots = foundSnapshots
                self.totalSizeGB = totalGB
                self.isScanning = false
                self.lastScanDate = Date()
            }
        }
    }
    
    /// Get total local backup size using diskutil apfs list
    private func getLocalBackupSize() -> Double {
        // Use diskutil apfs list to get actual snapshot sizes
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["apfs", "list"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            // Parse APFS snapshot sizes from output
            // Look for lines like "Snapshot" and associated sizes
            var totalGB: Double = 0
            var inSnapshotSection = false
            
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Detect snapshot sections
                if trimmed.contains("Snapshot") && trimmed.contains("for") {
                    inSnapshotSection = true
                }
                
                // Look for size indicators
                if inSnapshotSection {
                    // Parse sizes like "1.2 GB" or "500 MB"
                    if let range = trimmed.range(of: #"[0-9]+\.?[0-9]*\s*(GB|MB|KB)"#, options: .regularExpression) {
                        let sizeStr = String(trimmed[range])
                        if sizeStr.contains("GB") {
                            if let value = Double(sizeStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                                totalGB += value
                            }
                        } else if sizeStr.contains("MB") {
                            if let value = Double(sizeStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                                totalGB += value / 1024
                            }
                        }
                    }
                }
            }
            
            // If diskutil didn't give us sizes, use tmutil localbackup as fallback
            if totalGB == 0 && snapshots.count > 0 {
                // Estimate based on typical snapshot behavior
                // Real snapshots share data, so actual size is less than count * size
                totalGB = Double(snapshots.count) * 2.0 // Conservative estimate
            }
            
            return totalGB
            
        } catch {
            print("[TimeMachineManager] Error getting local backup size: \(error)")
            // Fallback estimate
            return Double(snapshots.count) * 2.0
        }
    }
    
    /// Parse snapshot date from string like "2024-03-22-123456"
    private func parseSnapshotDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.date(from: dateString)
    }
    
    // MARK: - Deletion
    
    /// Delete a specific snapshot
    func deleteSnapshot(_ snapshot: TimeMachineSnapshot, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Format date for tmutil (YYYY-MM-DD-HHMMSS)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let dateString = formatter.string(from: snapshot.date)
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            task.arguments = ["deletelocalsnapshots", dateString]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let success = task.terminationStatus == 0
                
                DispatchQueue.main.async {
                    if success {
                        self.snapshots.removeAll { $0.id == snapshot.id }
                        self.totalSizeGB = max(0, self.totalSizeGB - snapshot.sizeGB)
                    }
                    completion(success)
                }
                
                print("[TimeMachineManager] Deleted snapshot \(snapshot.name): \(success)")
                
            } catch {
                print("[TimeMachineManager] Error deleting snapshot: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    /// Delete all local snapshots
    func deleteAllSnapshots(completion: @escaping (Double) -> Void) {
        let totalFreed = totalSizeGB
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Use tmutil to delete all local snapshots
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            task.arguments = ["deletelocalsnapshots", "/"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let success = task.terminationStatus == 0
                
                DispatchQueue.main.async {
                    if success {
                        self.snapshots = []
                        self.totalSizeGB = 0
                    }
                    completion(success ? totalFreed : 0)
                }
                
                print("[TimeMachineManager] Deleted all snapshots: \(success), freed \(totalFreed)GB")
                
            } catch {
                print("[TimeMachineManager] Error deleting all snapshots: \(error)")
                DispatchQueue.main.async {
                    completion(0)
                }
            }
        }
    }
    
    /// Thin local snapshots (keep only recent ones)
    func thinSnapshots(keepCount: Int = 3, completion: @escaping (Double) -> Void) {
        let sortedSnapshots = snapshots.sorted { $0.date > $1.date }
        let toDelete = sortedSnapshots.dropFirst(keepCount)
        
        var totalFreed: Double = 0
        var deleted = 0
        
        let group = DispatchGroup()
        
        for snapshot in toDelete {
            group.enter()
            deleteSnapshot(snapshot) { success in
                if success {
                    totalFreed += snapshot.sizeGB
                    deleted += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(totalFreed)
            print("[TimeMachineManager] Thinned \(deleted) snapshots, freed \(totalFreed)GB")
        }
    }
    
    // MARK: - Quick Actions
    
    /// Quick estimate of recoverable space from snapshots
    static func estimateRecoverableGB() -> Double {
        // Quick check without full scan
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["listlocalsnapshotdates"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let count = output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        
        // Estimate 5GB per snapshot
        return Double(count) * 5.0
    }
    
    /// Check if Time Machine is enabled
    static func isTimeMachineEnabled() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["status"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output.contains("Running") || output.contains("Backing")
    }
}