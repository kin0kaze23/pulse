import Foundation

/// Comprehensive storage analyzer for finding recoverable disk space
/// Scans: iOS updates, node_modules, large files, iOS backups, downloads, messages
class StorageAnalyzer: ObservableObject {
    static let shared = StorageAnalyzer()
    
    @Published var isScanning = false
    @Published var lastScanDate: Date?
    @Published var scanProgress: Double = 0
    @Published var statusMessage: String = ""
    
    // Scan results
    @Published var iosUpdates: [StorageItem] = []
    @Published var nodeModulesFolders: [StorageItem] = []
    @Published var largeFiles: [StorageItem] = []
    @Published var iosBackups: [StorageItem] = []
    @Published var downloadsItems: [StorageItem] = []
    @Published var messagesAttachments: [StorageItem] = []
    
    // Totals
    @Published var totalIOSUpdatesGB: Double = 0
    @Published var totalNodeModulesGB: Double = 0
    @Published var totalLargeFilesGB: Double = 0
    @Published var totalIOSBackupsGB: Double = 0
    @Published var totalDownloadsGB: Double = 0
    @Published var totalMessagesGB: Double = 0
    @Published var totalRecoverableGB: Double = 0
    
    // MARK: - Storage Item
    
    struct StorageItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let sizeGB: Double
        let category: Category
        let isDeletable: Bool
        let warningMessage: String?
        let lastModified: Date?
        
        var sizeText: String {
            if sizeGB >= 1 {
                return String(format: "%.1f GB", sizeGB)
            }
            return String(format: "%.0f MB", sizeGB * 1024)
        }
        
        var ageText: String? {
            guard let date = lastModified else { return nil }
            let interval = Date().timeIntervalSince(date)
            let days = Int(interval / 86400)
            if days == 0 { return "Today" }
            if days == 1 { return "Yesterday" }
            if days < 7 { return "\(days) days ago" }
            if days < 30 { return "\(days / 7) weeks ago" }
            if days < 365 { return "\(days / 30) months ago" }
            return "\(days / 365) years ago"
        }
        
        enum Category: String {
            case iosUpdate = "iOS Update"
            case nodeModules = "node_modules"
            case largeFile = "Large File"
            case iosBackup = "iOS Backup"
            case download = "Download"
            case messages = "Messages"
            
            var icon: String {
                switch self {
                case .iosUpdate: return "iphone"
                case .nodeModules: return "cube.box"
                case .largeFile: return "doc.fill"
                case .iosBackup: return "externaldrive.fill"
                case .download: return "arrow.down.circle.fill"
                case .messages: return "message.fill"
                }
            }
            
            var color: String {
                switch self {
                case .iosUpdate: return "blue"
                case .nodeModules: return "green"
                case .largeFile: return "orange"
                case .iosBackup: return "purple"
                case .download: return "cyan"
                case .messages: return "red"
                }
            }
        }
    }
    
    private init() {}
    
    // MARK: - Full Scan
    
    /// Run a comprehensive storage scan
    func scanAll() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        statusMessage = "Starting scan..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Phase 1: iOS Updates (quick)
            DispatchQueue.main.async { self.statusMessage = "Scanning iOS updates..."; self.scanProgress = 0.1 }
            self.scanIOSUpdates()
            
            // Phase 2: node_modules (can be slow)
            DispatchQueue.main.async { self.statusMessage = "Scanning node_modules..."; self.scanProgress = 0.3 }
            self.scanNodeModules()
            
            // Phase 3: iOS Backups (quick)
            DispatchQueue.main.async { self.statusMessage = "Scanning iOS backups..."; self.scanProgress = 0.5 }
            self.scanIOSBackups()
            
            // Phase 4: Large Files (can be slow)
            DispatchQueue.main.async { self.statusMessage = "Finding large files..."; self.scanProgress = 0.7 }
            self.scanLargeFiles()
            
            // Phase 5: Downloads (quick)
            DispatchQueue.main.async { self.statusMessage = "Scanning downloads..."; self.scanProgress = 0.85 }
            self.scanDownloads()
            
            // Phase 6: Messages (quick)
            DispatchQueue.main.async { self.statusMessage = "Scanning messages..."; self.scanProgress = 0.95 }
            self.scanMessagesAttachments()
            
            // Calculate totals
            let total = self.totalIOSUpdatesGB + self.totalNodeModulesGB + 
                       self.totalLargeFilesGB + self.totalIOSBackupsGB + 
                       self.totalDownloadsGB + self.totalMessagesGB
            
            DispatchQueue.main.async {
                self.totalRecoverableGB = total
                self.isScanning = false
                self.scanProgress = 1.0
                self.statusMessage = ""
                self.lastScanDate = Date()
                
                print("[StorageAnalyzer] Scan complete: \(total)GB recoverable")
            }
        }
    }
    
    // MARK: - Individual Scanners
    
    /// Scan for iOS/macOS update files (.ipsw, .dmg)
    func scanIOSUpdates() {
        var items: [StorageItem] = []
        var totalGB: Double = 0
        
        let paths = [
            NSString(string: "~/Library/iTunes/iOS Updates").expandingTildeInPath,
            NSString(string: "~/Library/Updates").expandingTildeInPath,
            "/Library/Updates"
        ]
        
        for expandedPath in paths {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: expandedPath) else { continue }
            
            for file in files {
                let filePath = expandedPath + "/" + file
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath) else { continue }
                guard let size = attrs[FileAttributeKey.size] as? Int64 else { continue }
                let modified = attrs[FileAttributeKey.modificationDate] as? Date
                
                let sizeGB = Double(size) / (1024 * 1024 * 1024)
                guard sizeGB > 0.01 else { continue } // Skip tiny files
                
                items.append(StorageItem(
                    name: file,
                    path: filePath,
                    sizeGB: sizeGB,
                    category: .iosUpdate,
                    isDeletable: true,
                    warningMessage: "Apple can re-download this if needed",
                    lastModified: modified
                ))
                
                totalGB += sizeGB
            }
        }
        
        DispatchQueue.main.async {
            self.iosUpdates = items
            self.totalIOSUpdatesGB = totalGB
        }
    }
    
    /// Scan for node_modules folders
    func scanNodeModules() {
        var items: [StorageItem] = []
        var totalGB: Double = 0
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let searchPaths = [
            home.path,
            home.appendingPathComponent("Developer").path,
            home.appendingPathComponent("Projects").path,
            home.appendingPathComponent("Code").path,
            home.appendingPathComponent("workspace").path
        ]
        
        for searchPath in searchPaths {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey, .totalFileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            
            let maxDepth = 5 // Don't go too deep
            
            for case let url as URL in enumerator {
                // Check depth
                let pathComponents = url.pathComponents
                let relativeDepth = pathComponents.count - URL(fileURLWithPath: searchPath).pathComponents.count
                if relativeDepth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
                
                // Look for node_modules
                if url.lastPathComponent == "node_modules" {
                    let sizeGB = DirectorySizeUtility.directorySizeGB(url.path)
                    guard sizeGB > 0.01 else { continue }
                    
                    // Get parent folder name for context
                    let parentName = url.deletingLastPathComponent().lastPathComponent
                    
                    items.append(StorageItem(
                        name: parentName.isEmpty ? "node_modules" : "\(parentName)/node_modules",
                        path: url.path,
                        sizeGB: sizeGB,
                        category: .nodeModules,
                        isDeletable: true,
                        warningMessage: "Run 'npm install' to restore",
                        lastModified: nil
                    ))
                    
                    totalGB += sizeGB
                    
                    // Skip contents of node_modules
                    enumerator.skipDescendants()
                }
            }
        }
        
        // Sort by size
        items.sort { $0.sizeGB > $1.sizeGB }
        
        DispatchQueue.main.async {
            self.nodeModulesFolders = items
            self.totalNodeModulesGB = totalGB
        }
    }
    
    /// Scan for iOS device backups
    func scanIOSBackups() {
        var items: [StorageItem] = []
        var totalGB: Double = 0
        
        let backupPath = NSString(string: "~/Library/Application Support/MobileSync/Backup").expandingTildeInPath
        
        guard let backupDirs = try? FileManager.default.contentsOfDirectory(atPath: backupPath) else {
            DispatchQueue.main.async {
                self.iosBackups = []
                self.totalIOSBackupsGB = 0
            }
            return
        }
        
        for dir in backupDirs {
            let dirPath = backupPath + "/" + dir
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else { continue }
            
            let sizeGB = DirectorySizeUtility.directorySizeGB(dirPath)
            guard sizeGB > 0.01 else { continue }
            
            // Try to get device name from Info.plist
            let infoPath = dirPath + "/Info.plist"
            var deviceName = "iOS Backup"
            var lastModified: Date?
            
            if let info = NSDictionary(contentsOfFile: infoPath) {
                deviceName = info["Device Name"] as? String ?? "iOS Backup"
            }
            
            if let attrs = try? FileManager.default.attributesOfItem(atPath: dirPath) {
                lastModified = attrs[FileAttributeKey.modificationDate] as? Date
            }
            
            items.append(StorageItem(
                name: deviceName,
                path: dirPath,
                sizeGB: sizeGB,
                category: .iosBackup,
                isDeletable: true,
                warningMessage: "⚠️ This backup will be permanently deleted",
                lastModified: lastModified
            ))
            
            totalGB += sizeGB
        }
        
        // Sort by date (newest first)
        items.sort { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        
        DispatchQueue.main.async {
            self.iosBackups = items
            self.totalIOSBackupsGB = totalGB
        }
    }
    
    /// Scan for large files (>100MB)
    func scanLargeFiles() {
        var items: [StorageItem] = []
        var totalGB: Double = 0
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        // Search in common locations
        let searchPaths = [
            home.appendingPathComponent("Downloads").path,
            home.appendingPathComponent("Documents").path,
            home.appendingPathComponent("Desktop").path,
            home.appendingPathComponent("Movies").path
        ]
        
        let minSizeGB: Double = 0.1 // 100MB minimum
        
        for searchPath in searchPaths {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for case let url as URL in enumerator {
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    guard resourceValues.isDirectory != true else { continue }
                    guard let fileSize = resourceValues.fileSize else { continue }
                    
                    let sizeGB = Double(fileSize) / (1024 * 1024 * 1024)
                    guard sizeGB >= minSizeGB else { continue }
                    
                    // Skip node_modules and other known folders
                    if url.path.contains("node_modules") { continue }
                    if url.path.contains(".git") { continue }
                    
                    items.append(StorageItem(
                        name: url.lastPathComponent,
                        path: url.path,
                        sizeGB: sizeGB,
                        category: .largeFile,
                        isDeletable: true,
                        warningMessage: nil,
                        lastModified: nil
                    ))
                    
                    totalGB += sizeGB
                    
                } catch { continue }
            }
        }
        
        // Sort by size, keep top 20
        items.sort { $0.sizeGB > $1.sizeGB }
        let topItems = Array(items.prefix(20))
        let topTotal = topItems.reduce(0) { $0 + $1.sizeGB }
        
        DispatchQueue.main.async {
            self.largeFiles = topItems
            self.totalLargeFilesGB = topTotal
        }
    }
    
    /// Scan Downloads folder for old files
    func scanDownloads() {
        var items: [StorageItem] = []
        var totalGB: Double = 0
        
        let downloadsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: downloadsPath) else {
            DispatchQueue.main.async {
                self.downloadsItems = []
                self.totalDownloadsGB = 0
            }
            return
        }
        
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        for file in files {
            let filePath = downloadsPath + "/" + file
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir)
            
            let sizeGB: Double
            let modified: Date?
            
            if isDir.boolValue {
                sizeGB = DirectorySizeUtility.directorySizeGB(filePath)
                modified = nil
            } else {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: filePath) else { continue }
                guard let size = attrs[FileAttributeKey.size] as? Int64 else { continue }
                sizeGB = Double(size) / (1024 * 1024 * 1024)
                modified = attrs[FileAttributeKey.modificationDate] as? Date
            }
            
            guard sizeGB > 0.01 else { continue }
            guard let modDate = modified, modDate < thirtyDaysAgo else { continue }
            
            items.append(StorageItem(
                name: file,
                path: filePath,
                sizeGB: sizeGB,
                category: .download,
                isDeletable: true,
                warningMessage: "Modified \(modDate.timeAgo())",
                lastModified: modDate
            ))
            
            totalGB += sizeGB
        }
        
        // Sort by size, keep top 10
        items.sort { $0.sizeGB > $1.sizeGB }
        let topItems = Array(items.prefix(10))
        
        DispatchQueue.main.async {
            self.downloadsItems = topItems
            self.totalDownloadsGB = topItems.reduce(0) { $0 + $1.sizeGB }
        }
    }
    
    /// Scan Messages attachments
    func scanMessagesAttachments() {
        var totalGB: Double = 0
        
        // Messages attachments are stored in:
        // ~/Library/Messages/Attachments
        let attachmentsPath = NSString(string: "~/Library/Messages/Attachments").expandingTildeInPath
        
        let sizeGB = DirectorySizeUtility.directorySizeGB(attachmentsPath)
        totalGB = sizeGB
        
        var items: [StorageItem] = []
        if sizeGB > 0.1 {
            items.append(StorageItem(
                name: "Messages Attachments",
                path: attachmentsPath,
                sizeGB: sizeGB,
                category: .messages,
                isDeletable: true,
                warningMessage: "⚠️ This will delete sent/received images and files",
                lastModified: nil
            ))
        }
        
        DispatchQueue.main.async {
            self.messagesAttachments = items
            self.totalMessagesGB = totalGB
        }
    }
    
    // MARK: - Quick Estimates
    
    /// Quick estimate of total recoverable space without full scan
    static func quickEstimateRecoverableGB() -> Double {
        var total: Double = 0
        
        // iOS updates
        let iosUpdatesPath = NSString(string: "~/Library/iTunes/iOS Updates").expandingTildeInPath
        if let files = try? FileManager.default.contentsOfDirectory(atPath: iosUpdatesPath) {
            total += Double(files.count) * 3.0 // Estimate 3GB per update
        }
        
        // Time Machine snapshots
        total += TimeMachineManager.estimateRecoverableGB()
        
        // node_modules (rough estimate)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        task.arguments = [home.path, "-name", "node_modules", "-type", "d", "-maxdepth", "4"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let count = output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        total += Double(count) * 0.5 // Estimate 500MB per node_modules
        
        return total
    }
    
    // MARK: - Cleanup Actions
    
    /// Validate that a path is safe to delete
    private func isPathSafeToDelete(_ path: String) -> Bool {
        let lowerPath = path.lowercased()
        
        // Protect critical system paths
        let protectedPrefixes = [
            "/system", "/bin", "/sbin", "/usr", "/var", "/etc",
            "/applications", "/library", "/network", "/cores",
            "/dev", "/private"
        ]
        
        for protected in protectedPrefixes {
            if lowerPath.hasPrefix(protected) {
                return false
            }
        }
        
        // Protect user home directory root and important folders
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path == homeDir || 
           path.hasPrefix(homeDir + "/Documents") || 
           path.hasPrefix(homeDir + "/Desktop") {
            return false
        }
        
        // Protect app bundles
        if lowerPath.hasSuffix(".app") || lowerPath.hasSuffix(".app/") {
            return false
        }
        
        return true
    }

    /// Delete iOS update file with safety checks
    func deleteIOSUpdate(_ item: StorageItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Safety check 1: Validate path
            guard self.isPathSafeToDelete(item.path) else {
                print("[StorageAnalyzer] Blocked deletion of protected path: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 2: Verify file exists
            guard FileManager.default.fileExists(atPath: item.path) else {
                print("[StorageAnalyzer] File does not exist: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                try FileManager.default.removeItem(atPath: item.path)
                print("[StorageAnalyzer] Deleted iOS update: \(item.path)")

                DispatchQueue.main.async {
                    self.iosUpdates.removeAll { $0.id == item.id }
                    self.totalIOSUpdatesGB = max(0, self.totalIOSUpdatesGB - item.sizeGB)
                    self.totalRecoverableGB = max(0, self.totalRecoverableGB - item.sizeGB)
                    completion(true)
                }
            } catch {
                print("[StorageAnalyzer] Error deleting iOS update: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    /// Delete node_modules folder with safety checks
    func deleteNodeModules(_ item: StorageItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Safety check 1: Validate path
            guard self.isPathSafeToDelete(item.path) else {
                print("[StorageAnalyzer] Blocked deletion of protected path: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 2: Verify directory exists and is node_modules
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else {
                print("[StorageAnalyzer] Path is not a directory: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 3: Verify it's actually a node_modules folder
            guard item.path.contains("node_modules") else {
                print("[StorageAnalyzer] Path does not contain node_modules: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                try FileManager.default.removeItem(atPath: item.path)
                print("[StorageAnalyzer] Deleted node_modules: \(item.path)")

                DispatchQueue.main.async {
                    self.nodeModulesFolders.removeAll { $0.id == item.id }
                    self.totalNodeModulesGB = max(0, self.totalNodeModulesGB - item.sizeGB)
                    self.totalRecoverableGB = max(0, self.totalRecoverableGB - item.sizeGB)
                    completion(true)
                }
            } catch {
                print("[StorageAnalyzer] Error deleting node_modules: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    /// Delete iOS backup with safety checks
    func deleteIOSBackup(_ item: StorageItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Safety check 1: Validate path
            guard self.isPathSafeToDelete(item.path) else {
                print("[StorageAnalyzer] Blocked deletion of protected path: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 2: Verify it's in the MobileSync backup location
            guard item.path.contains("MobileSync/Backup") else {
                print("[StorageAnalyzer] Path is not in MobileSync/Backup: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 3: Verify directory exists
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else {
                print("[StorageAnalyzer] Backup directory does not exist: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                try FileManager.default.removeItem(atPath: item.path)
                print("[StorageAnalyzer] Deleted iOS backup: \(item.path)")

                DispatchQueue.main.async {
                    self.iosBackups.removeAll { $0.id == item.id }
                    self.totalIOSBackupsGB = max(0, self.totalIOSBackupsGB - item.sizeGB)
                    self.totalRecoverableGB = max(0, self.totalRecoverableGB - item.sizeGB)
                    completion(true)
                }
            } catch {
                print("[StorageAnalyzer] Error deleting iOS backup: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    /// Delete large file with safety checks
    func deleteLargeFile(_ item: StorageItem, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Safety check 1: Validate path
            guard self.isPathSafeToDelete(item.path) else {
                print("[StorageAnalyzer] Blocked deletion of protected path: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 2: Verify file exists
            guard FileManager.default.fileExists(atPath: item.path) else {
                print("[StorageAnalyzer] File does not exist: \(item.path)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Safety check 3: Check if file is in use
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
            task.arguments = [item.path]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), 
                   !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("[StorageAnalyzer] File is in use, skipping: \(item.path)")
                    DispatchQueue.main.async { completion(false) }
                    return
                }
            } catch {
                print("[StorageAnalyzer] lsof check failed for \(item.path): \(error)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                try FileManager.default.removeItem(atPath: item.path)
                print("[StorageAnalyzer] Deleted large file: \(item.path)")

                DispatchQueue.main.async {
                    self.largeFiles.removeAll { $0.id == item.id }
                    self.totalLargeFilesGB = max(0, self.totalLargeFilesGB - item.sizeGB)
                    self.totalRecoverableGB = max(0, self.totalRecoverableGB - item.sizeGB)
                    completion(true)
                }
            } catch {
                print("[StorageAnalyzer] Error deleting file: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgo() -> String {
        let interval = Date().timeIntervalSince(self)
        let days = Int(interval / 86400)
        
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(days) days ago" }
        if days < 30 { return "\(days / 7) weeks ago" }
        if days < 365 { return "\(days / 30) months ago" }
        return "\(days / 365) years ago"
    }
}