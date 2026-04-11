import XCTest
@testable import Pulse

final class LargeFileFinderTests: XCTestCase {

    var finder: LargeFileFinder!

    override func setUp() {
        super.setUp()
        finder = LargeFileFinder.shared
    }

    // MARK: - Scan Configuration Tests

    func testDefaultMinimumSize() {
        XCTAssertEqual(finder.configuration.minimumSizeMB, 100)
    }

    func testDefaultDirectoriesToScan() {
        XCTAssertFalse(finder.configuration.directoriesToScan.isEmpty)
        XCTAssertTrue(finder.configuration.directoriesToScan.contains(NSHomeDirectory()))
    }

    func testDefaultExcludedDirectories() {
        let excluded = finder.configuration.excludedDirectories
        XCTAssertTrue(excluded.contains("/System"))
        XCTAssertTrue(excluded.contains("/private/var/vm"))
    }

    func testProtectedPathsConfiguration() {
        let testPath = "/Users/test/Protected"
        finder.configuration.addProtectedPath(testPath)

        XCTAssertTrue(finder.configuration.isProtected(testPath))
        XCTAssertFalse(finder.configuration.isProtected("/Users/test/Unprotected"))
    }

    // MARK: - File Category Tests

    func testFileCategoryFromExtension() {
        XCTAssertEqual(FileCategory.from(extension: "jpg"), .media)
        XCTAssertEqual(FileCategory.from(extension: "png"), .media)
        XCTAssertEqual(FileCategory.from(extension: "zip"), .archives)
        XCTAssertEqual(FileCategory.from(extension: "pdf"), .documents)
        XCTAssertEqual(FileCategory.from(extension: "app"), .applications)
        XCTAssertEqual(FileCategory.from(extension: "log"), .logs)
        XCTAssertEqual(FileCategory.from(extension: "cache"), .cache)
        XCTAssertEqual(FileCategory.from(extension: "xyz"), .other)
    }

    func testFileCategoryCaseInsensitive() {
        XCTAssertEqual(FileCategory.from(extension: "JPG"), .media)
        XCTAssertEqual(FileCategory.from(extension: "PDF"), .documents)
    }

    // MARK: - LargeFileScanResult Tests

    func testLargeFileScanResultProperties() {
        let result = LargeFileScanResult(
            path: "/Users/test/file.zip",
            name: "file.zip",
            sizeBytes: 150_000_000, // 150 MB
            modificationDate: Date()
        )

        XCTAssertEqual(result.name, "file.zip")
        XCTAssertEqual(result.sizeBytes, 150_000_000)
        XCTAssertEqual(result.fileExtension, "zip")
        XCTAssertEqual(result.category, .archives)
    }

    func testLargeFileScanResultFormattedSize() {
        let smallFile = LargeFileScanResult(
            path: "/test.txt",
            name: "test.txt",
            sizeBytes: 50_000, // 50 KB (binary: 48.8 KB -> rounds to 49 KB)
            modificationDate: Date()
        )
        XCTAssertEqual(smallFile.formattedSize, "49 KB")

        let mediumFile = LargeFileScanResult(
            path: "/test.txt",
            name: "test.txt",
            sizeBytes: 50_000_000, // 50 MB (binary: 47.7 MB)
            modificationDate: Date()
        )
        XCTAssertEqual(mediumFile.formattedSize, "47.7 MB")

        let largeFile = LargeFileScanResult(
            path: "/test.txt",
            name: "test.txt",
            sizeBytes: 2_000_000_000, // 2 GB
            modificationDate: Date()
        )
        XCTAssertEqual(largeFile.formattedSize, "1.86 GB")
    }

    func testLargeFileScanResultParentDirectory() {
        let result = LargeFileScanResult(
            path: "/Users/test/Documents/file.pdf",
            name: "file.pdf",
            sizeBytes: 1_000_000,
            modificationDate: Date()
        )

        XCTAssertEqual(result.parentDirectory, "/Users/test/Documents")
    }

    // MARK: - Scan Progress Tests

    func testScanProgressStates() {
        let idle: ScanProgress = .idle
        XCTAssertFalse(idle.isScanning)

        let scanning: ScanProgress = .scanning(currentPath: "/test", filesScanned: 100)
        XCTAssertTrue(scanning.isScanning)

        let completed: ScanProgress = .completed(results: [])
        XCTAssertFalse(completed.isScanning)

        let failed: ScanProgress = .failed(error: "Test error")
        XCTAssertFalse(failed.isScanning)
    }

    func testScanProgressText() {
        let idle = ScanProgress.idle
        XCTAssertEqual(idle.progressText, "Ready to scan")

        let scanning = ScanProgress.scanning(currentPath: "/test", filesScanned: 500)
        XCTAssertTrue(scanning.progressText.contains("500"))

        let completed = ScanProgress.completed(results: [LargeFileScanResult(
            path: "/test",
            name: "test",
            sizeBytes: 100,
            modificationDate: Date()
        )])
        XCTAssertTrue(completed.progressText.contains("1"))
    }

    // MARK: - Sort Option Tests

    func testSortOptionsCount() {
        XCTAssertEqual(LargeFileSortOption.allCases.count, 6)
    }

    // MARK: - Scan Statistics Tests

    func testScanStatisticsProperties() {
        let stats = ScanStatistics(
            totalFilesScanned: 10000,
            totalSizeScanned: 500_000_000_000,
            scanDuration: 45.5,
            largeFilesFound: 25
        )

        XCTAssertEqual(stats.totalFilesScanned, 10000)
        XCTAssertEqual(stats.formattedTotalSize, "465.66 GB")
        XCTAssertEqual(stats.formattedDuration, "45.5 seconds")
        XCTAssertEqual(stats.largeFilesFound, 25)
    }
}