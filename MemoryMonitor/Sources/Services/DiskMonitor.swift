import Foundation

/// Monitors disk usage across all mounted volumes
class DiskMonitor: ObservableObject {
    static let shared = DiskMonitor()

    @Published var disks: [DiskInfo] = []
    @Published var primaryDisk: DiskInfo?

    struct DiskInfo: Identifiable {
        let id = UUID()
        let name: String
        let mountPath: String
        let totalBytes: UInt64
        let freeBytes: UInt64
        let usedBytes: UInt64
        let isRemovable: Bool
        let fileSystem: String

        var usedPercentage: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(usedBytes) / Double(totalBytes) * 100.0
        }

        var totalGB: Double { Double(totalBytes) / (1024 * 1024 * 1024) }
        var freeGB: Double { Double(freeBytes) / (1024 * 1024 * 1024) }
        var usedGB: Double { Double(usedBytes) / (1024 * 1024 * 1024) }
    }

    private init() {}

    // MARK: - Refresh

    func refresh() {
        var results: [DiskInfo] = []

        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeLocalizedFormatDescriptionKey
        ]

        guard let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return }

        for url in volumes {
            guard let resources = try? url.resourceValues(forKeys: Set(keys)) else { continue }

            let name = resources.volumeName ?? url.lastPathComponent
            let total = UInt64(resources.volumeTotalCapacity ?? 0)
            let free = UInt64(resources.volumeAvailableCapacity ?? 0)
            let used = total > free ? total - free : 0
            let isRemovable = resources.volumeIsRemovable ?? false
            let fs = resources.volumeLocalizedFormatDescription ?? "Unknown"

            let disk = DiskInfo(
                name: name,
                mountPath: url.path,
                totalBytes: total,
                freeBytes: free,
                usedBytes: used,
                isRemovable: isRemovable,
                fileSystem: fs
            )

            results.append(disk)

            if url.path == "/" {
                DispatchQueue.main.async {
                    self.primaryDisk = disk
                }
            }
        }

        DispatchQueue.main.async {
            self.disks = results
        }
    }

    // MARK: - Large Files Finder

    func findLargeFiles(in path: String = "/Users", minSizeMB: Double = 100, limit: Int = 20) -> [LargeFile] {
        var results: [LargeFile] = []

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: URL(fileURLWithPath: path),
                                              includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                                              options: [.skipsHiddenFiles]) else { return results }

        let minSizeBytes = Int64(minSizeMB * 1024 * 1024)

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let size = resourceValues.fileSize,
                  Int64(size) >= minSizeBytes else { continue }

            results.append(LargeFile(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                sizeBytes: UInt64(size)
            ))

            if results.count >= limit * 3 { break } // Get extra to sort
        }

        return Array(results.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(limit))
    }

    struct LargeFile: Identifiable {
        let id = UUID()
        let path: String
        let name: String
        let sizeBytes: UInt64

        var sizeGB: Double { Double(sizeBytes) / (1024 * 1024 * 1024) }
        var sizeMB: Double { Double(sizeBytes) / (1024 * 1024) }
    }
}
