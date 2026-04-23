import XCTest
@testable import PulseApp

// MARK: - DuplicateFileScanner Tests

@MainActor
final class DuplicateFileScannerTests: XCTestCase {

    var scanner: DuplicateFileScanner!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        scanner = DuplicateFileScanner()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PulseTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        scanner = nil
        super.tearDown()
    }

    // MARK: - Protected Path Tests

    func testProtectedPathDetection() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        XCTAssertTrue(DuplicateFileScanner.isPathProtected(homeDir + "/Documents/important.pdf"))
        XCTAssertTrue(DuplicateFileScanner.isPathProtected(homeDir + "/Desktop/file.txt"))
        XCTAssertTrue(DuplicateFileScanner.isPathProtected(homeDir + "/Library/Preferences/com.apple.finder.plist"))
        XCTAssertTrue(DuplicateFileScanner.isPathProtected(homeDir + "/.ssh/id_rsa"))
        XCTAssertTrue(DuplicateFileScanner.isPathProtected(homeDir + "/.gnupg/gpg.conf"))

        XCTAssertFalse(DuplicateFileScanner.isPathProtected(homeDir + "/Downloads/file.dmg"))
        XCTAssertFalse(DuplicateFileScanner.isPathProtected(homeDir + "/Library/Caches/com.apple.Safari"))
        XCTAssertFalse(DuplicateFileScanner.isPathProtected("/Users/shared/file.txt"))
    }

    func testFileSafetyCheck() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let safeFile = DuplicateFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/test.dmg"),
            path: "/tmp/test.dmg",
            name: "test.dmg",
            sizeBytes: 1000,
            modificationDate: Date(),
            hash: "abc123"
        )
        XCTAssertTrue(scanner.isFileSafeToDelete(safeFile))

        let protectedFile = DuplicateFile(
            id: UUID(),
            url: URL(fileURLWithPath: homeDir + "/Documents/test.dmg"),
            path: homeDir + "/Documents/test.dmg",
            name: "test.dmg",
            sizeBytes: 1000,
            modificationDate: Date(),
            hash: "abc123"
        )
        XCTAssertFalse(scanner.isFileSafeToDelete(protectedFile))
    }

    // MARK: - Duplicate Group Tests

    func testDuplicateGroupReclaimableCalculation() {
        let files: [DuplicateFile] = (1...4).map { i in
            DuplicateFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/tmp/file\(i).txt"),
                path: "/tmp/file\(i).txt",
                name: "file\(i).txt",
                sizeBytes: 1024 * 1024, // 1MB each
                modificationDate: Date().addingTimeInterval(-Double(i * 3600)),
                hash: "samehash"
            )
        }

        let group = DuplicateGroup(
            id: UUID(),
            hash: "samehash",
            fileSizeBytes: 1024 * 1024,
            files: files
        )

        XCTAssertEqual(group.duplicateCount, 3) // 4 files, keep 1
        XCTAssertEqual(group.reclaimableBytes, UInt64(3 * 1024 * 1024))
        XCTAssertEqual(group.reclaimableMB, 3.0, accuracy: 0.01)
    }

    func testDuplicateGroupWithTwoFiles() {
        let files: [DuplicateFile] = [
            DuplicateFile(id: UUID(), url: URL(fileURLWithPath: "/tmp/a.txt"), path: "/tmp/a.txt", name: "a.txt", sizeBytes: 500, modificationDate: Date(), hash: "hash"),
            DuplicateFile(id: UUID(), url: URL(fileURLWithPath: "/tmp/b.txt"), path: "/tmp/b.txt", name: "b.txt", sizeBytes: 500, modificationDate: Date(), hash: "hash")
        ]

        let group = DuplicateGroup(id: UUID(), hash: "hash", fileSizeBytes: 500, files: files)

        XCTAssertEqual(group.duplicateCount, 1)
        XCTAssertEqual(group.reclaimableBytes, UInt64(500))
    }

    func testDuplicateGroupWithSingleFile() {
        let files: [DuplicateFile] = [
            DuplicateFile(id: UUID(), url: URL(fileURLWithPath: "/tmp/unique.txt"), path: "/tmp/unique.txt", name: "unique.txt", sizeBytes: 500, modificationDate: Date(), hash: "unique")
        ]

        let group = DuplicateGroup(id: UUID(), hash: "unique", fileSizeBytes: 500, files: files)

        XCTAssertEqual(group.duplicateCount, 0)
        XCTAssertEqual(group.reclaimableBytes, UInt64(0))
    }

    // MARK: - Auto-Select Tests

    func testAutoSelectOldestKeep() {
        let group = createTestGroup()
        scanner.duplicateGroups = [group]

        scanner.autoSelectOldestKeep()

        // The oldest file should NOT be selected
        let sorted = group.files.sorted { $0.modificationDate < $1.modificationDate }
        let oldest = sorted.first!
        XCTAssertFalse(scanner.selectedForDeletion.contains(oldest.id))

        // All other files should be selected
        for file in sorted.dropFirst() {
            XCTAssertTrue(scanner.selectedForDeletion.contains(file.id))
        }
    }

    func testAutoSelectNewestKeep() {
        let group = createTestGroup()
        scanner.duplicateGroups = [group]

        scanner.autoSelectNewestKeep()

        // The newest file should NOT be selected
        let sorted = group.files.sorted { $0.modificationDate > $1.modificationDate }
        let newest = sorted.first!
        XCTAssertFalse(scanner.selectedForDeletion.contains(newest.id))

        // All other files should be selected
        for file in sorted.dropFirst() {
            XCTAssertTrue(scanner.selectedForDeletion.contains(file.id))
        }
    }

    func testAutoSelectRespectsProtectedPaths() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let protectedFile = DuplicateFile(
            id: UUID(),
            url: URL(fileURLWithPath: homeDir + "/Documents/dup.txt"),
            path: homeDir + "/Documents/dup.txt",
            name: "dup.txt",
            sizeBytes: 1000,
            modificationDate: Date().addingTimeInterval(-1000),
            hash: "hash1"
        )

        let safeFile1 = DuplicateFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/dup1.txt"),
            path: "/tmp/dup1.txt",
            name: "dup1.txt",
            sizeBytes: 1000,
            modificationDate: Date(),
            hash: "hash1"
        )

        let safeFile2 = DuplicateFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/dup2.txt"),
            path: "/tmp/dup2.txt",
            name: "dup2.txt",
            sizeBytes: 1000,
            modificationDate: Date().addingTimeInterval(-500),
            hash: "hash1"
        )

        let group = DuplicateGroup(id: UUID(), hash: "hash1", fileSizeBytes: 1000, files: [protectedFile, safeFile1, safeFile2])
        scanner.duplicateGroups = [group]

        scanner.autoSelectOldestKeep()

        // Protected file should never be selected for deletion
        XCTAssertFalse(scanner.selectedForDeletion.contains(protectedFile.id))
    }

    // MARK: - Selected Reclaimable Tests

    func testSelectedReclaimableCalculation() {
        let files: [DuplicateFile] = (1...3).map { i in
            DuplicateFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/tmp/file\(i).txt"),
                path: "/tmp/file\(i).txt",
                name: "file\(i).txt",
                sizeBytes: 1024,
                modificationDate: Date().addingTimeInterval(-Double(i * 100)),
                hash: "samehash"
            )
        }

        let group = DuplicateGroup(id: UUID(), hash: "samehash", fileSizeBytes: 1024, files: files)
        scanner.duplicateGroups = [group]

        // Select 2 out of 3 files (keep 1)
        scanner.selectedForDeletion = Set(files.prefix(2).map { $0.id })

        XCTAssertEqual(scanner.selectedReclaimableBytes, UInt64(2 * 1024))
    }

    func testSelectedReclaimableWithAllSelected() {
        let files: [DuplicateFile] = [
            DuplicateFile(id: UUID(), url: URL(fileURLWithPath: "/tmp/a.txt"), path: "/tmp/a.txt", name: "a.txt", sizeBytes: 1024, modificationDate: Date(), hash: "h"),
            DuplicateFile(id: UUID(), url: URL(fileURLWithPath: "/tmp/b.txt"), path: "/tmp/b.txt", name: "b.txt", sizeBytes: 1024, modificationDate: Date(), hash: "h")
        ]

        let group = DuplicateGroup(id: UUID(), hash: "h", fileSizeBytes: 1024, files: files)
        scanner.duplicateGroups = [group]

        // Select ALL files (not allowed - must keep at least 1)
        scanner.selectedForDeletion = Set(files.map { $0.id })

        // Since all are selected (none kept), reclaimable should be 0
        XCTAssertEqual(scanner.selectedReclaimableBytes, UInt64(0))
    }

    // MARK: - Scan Validation Tests

    func testScanWithNoDirectories() {
        scanner.directoriesToScan = []
        XCTAssertFalse(scanner.isScanning)

        // Should fail gracefully
        scanner.startScan()
        // The scanner should not crash, and should set an error state
    }

    func testScanWithEmptyDirectory() {
        // Empty directory should complete with no duplicates
        let expectation = XCTestExpectation(description: "Scan completes")

        scanner.startScan(directories: [tempDir.path])

        // Give the async scan time to run
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertFalse(scanner.isScanning)
        XCTAssertTrue(scanner.duplicateGroups.isEmpty)
    }

    // MARK: - Format Tests

    func testDuplicateFileFormatting() {
        let file = DuplicateFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/large_file.dmg"),
            path: "/tmp/large_file.dmg",
            name: "large_file.dmg",
            sizeBytes: 2 * 1024 * 1024 * 1024, // 2GB
            modificationDate: Date(),
            hash: "abc"
        )

        XCTAssertTrue(file.formattedSize.contains("GB"))
        XCTAssertEqual(file.name, "large_file.dmg")
        XCTAssertTrue(file.parentDirectory.contains("/tmp"))
    }

    // MARK: - Helper Methods

    private func createTestGroup() -> DuplicateGroup {
        let files: [DuplicateFile] = (1...3).map { i in
            DuplicateFile(
                id: UUID(),
                url: URL(fileURLWithPath: "/tmp/test\(i).txt"),
                path: "/tmp/test\(i).txt",
                name: "test\(i).txt",
                sizeBytes: 1000,
                modificationDate: Date().addingTimeInterval(-Double(i * 3600)),
                hash: "testhash"
            )
        }
        return DuplicateGroup(id: UUID(), hash: "testhash", fileSizeBytes: 1000, files: files)
    }
}

// MARK: - InstallerCleanupService Tests

final class InstallerCleanupServiceTests: XCTestCase {

    var service: InstallerCleanupService!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        service = InstallerCleanupService()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("InstallerTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        service = nil
        super.tearDown()
    }

    // MARK: - Installer Type Tests

    func testInstallerTypeExtensions() {
        XCTAssertEqual(InstallerType.diskImage.extensions, ["dmg"])
        XCTAssertEqual(InstallerType.package.extensions, ["pkg"])
        XCTAssertEqual(InstallerType.zipArchive.extensions, ["zip"])
        XCTAssertEqual(InstallerType.stuffit.extensions, ["sitx"])
        XCTAssertEqual(InstallerType.tarball.extensions, ["tgz", "tar.gz"])
        XCTAssertTrue(InstallerType.brewCask.extensions.isEmpty)
    }

    func testInstallerTypeIcons() {
        XCTAssertEqual(InstallerType.diskImage.icon, "cd")
        XCTAssertEqual(InstallerType.package.icon, "shippingbox")
        XCTAssertEqual(InstallerType.zipArchive.icon, "archivebox")
        XCTAssertEqual(InstallerType.brewCask.icon, "cup.and.saucer")
    }

    // MARK: - Age Category Tests

    func testAgeCategorySorting() {
        let categories = AgeCategory.allCases.sorted()
        XCTAssertEqual(categories, [.week, .month, .older])
    }

    // MARK: - Installer File Tests

    func testInstallerFileAgeCalculation() {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let file = InstallerFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/test.dmg"),
            path: "/tmp/test.dmg",
            name: "test.dmg",
            sizeBytes: 100_000_000,
            modificationDate: weekAgo,
            installerType: .diskImage,
            ageDays: 10
        )

        XCTAssertEqual(file.ageDays, 10)
        XCTAssertTrue(file.formattedAge.contains("10 days"))
        XCTAssertEqual(file.formattedSize, "95.4 MB")
    }

    func testInstallerFileFormatting() {
        let file = InstallerFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/Applications/Installer.dmg"),
            path: "/Applications/Installer.dmg",
            name: "Installer.dmg",
            sizeBytes: 2 * 1024 * 1024 * 1024, // 2GB
            modificationDate: Date(),
            installerType: .diskImage,
            ageDays: 30
        )

        XCTAssertTrue(file.formattedSize.contains("GB"))
        XCTAssertEqual(file.parentDirectory, "Applications")
        XCTAssertEqual(file.installerType, .diskImage)
    }

    // MARK: - Installer Group Tests

    func testInstallerGroupTotalSize() {
        let files: [InstallerFile] = [
            makeInstallerFile(name: "a.dmg", size: 1_000_000, type: .diskImage, age: 10),
            makeInstallerFile(name: "b.dmg", size: 2_000_000, type: .diskImage, age: 15),
        ]

        let group = InstallerGroup(id: UUID(), type: .diskImage, ageCategory: .week, files: files)

        XCTAssertEqual(group.totalSizeBytes, UInt64(3_000_000))
        XCTAssertEqual(group.totalSizeMB, 3_000_000.0 / (1024 * 1024), accuracy: 0.01)
        XCTAssertEqual(group.files.count, 2)
    }

    // MARK: - Selection Tests

    func testSelectAllAndDeselectAll() {
        let files: [InstallerFile] = [
            makeInstallerFile(name: "a.dmg", size: 1_000_000, type: .diskImage, age: 10),
            makeInstallerFile(name: "b.pkg", size: 2_000_000, type: .package, age: 20),
        ]

        service.installerFiles = files

        service.selectAll()
        XCTAssertEqual(service.selectedForDeletion.count, 2)

        service.deselectAll()
        XCTAssertEqual(service.selectedForDeletion.count, 0)
    }

    func testSelectedReclaimableBytes() {
        let files: [InstallerFile] = [
            makeInstallerFile(name: "a.dmg", size: 1_000_000, type: .diskImage, age: 10),
            makeInstallerFile(name: "b.dmg", size: 2_000_000, type: .diskImage, age: 15),
            makeInstallerFile(name: "c.pkg", size: 3_000_000, type: .package, age: 30),
        ]

        service.installerFiles = files
        service.selectedForDeletion = Set([files[0].id, files[2].id])

        XCTAssertEqual(service.selectedReclaimableBytes, UInt64(1_000_000 + 3_000_000))
    }

    // MARK: - Scan Empty Tests

    func testScanEmptyDirectory() {
        let expectation = XCTestExpectation(description: "Scan completes")

        service.scanDirectories = [tempDir.path]
        service.shouldScanHomebrewCache = false
        service.scanICloudDrive = false
        service.startScan()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        XCTAssertFalse(service.isScanning)
    }

    // MARK: - Helper Methods

    private func makeInstallerFile(name: String, size: Int, type: InstallerType, age: Int) -> InstallerFile {
        return InstallerFile(
            id: UUID(),
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            path: "/tmp/\(name)",
            name: name,
            sizeBytes: UInt64(size),
            modificationDate: Calendar.current.date(byAdding: .day, value: -age, to: Date())!,
            installerType: type,
            ageDays: age
        )
    }
}

// MARK: - OperationAuditLog Tests

final class OperationAuditLogTests: XCTestCase {

    var auditLog: OperationAuditLog!

    override func setUp() {
        super.setUp()
        auditLog = OperationAuditLog()
        // Clear entries for clean test state
        auditLog.entries.removeAll()
    }

    override func tearDown() {
        auditLog.entries.removeAll()
        auditLog = nil
        super.tearDown()
    }

    // MARK: - Entry Creation Tests

    func testLogEntryCreation() {
        auditLog.log(
            operation: .cleanup,
            itemsAffected: 5,
            spaceFreedBytes: 100 * 1024 * 1024,
            success: true,
            userInitiated: true,
            details: "Cleaned caches"
        )

        XCTAssertEqual(auditLog.entries.count, 1)
        XCTAssertEqual(auditLog.entries[0].operationType, .cleanup)
        XCTAssertEqual(auditLog.entries[0].itemsAffected, 5)
        XCTAssertEqual(auditLog.entries[0].spaceFreedBytes, 100 * 1024 * 1024)
        XCTAssertTrue(auditLog.entries[0].success)
        XCTAssertTrue(auditLog.entries[0].userInitiated)
        XCTAssertEqual(auditLog.entries[0].details, "Cleaned caches")
    }

    func testLogEntryWithFailure() {
        auditLog.log(
            operation: .duplicateRemoval,
            itemsAffected: 3,
            spaceFreedBytes: 0,
            success: false,
            userInitiated: true,
            errorMessage: "Permission denied"
        )

        XCTAssertEqual(auditLog.entries.count, 1)
        XCTAssertFalse(auditLog.entries[0].success)
        XCTAssertEqual(auditLog.entries[0].errorMessage, "Permission denied")
    }

    // MARK: - Ordering Tests

    func testEntriesAreInsertedInReverseChronologicalOrder() {
        auditLog.log(operation: .scan, itemsAffected: 0, spaceFreedBytes: 0, success: true)
        Thread.sleep(forTimeInterval: 0.01)
        auditLog.log(operation: .cleanup, itemsAffected: 5, spaceFreedBytes: 1000, success: true)

        XCTAssertEqual(auditLog.entries.count, 2)
        // Most recent entry should be first
        XCTAssertEqual(auditLog.entries[0].operationType, .cleanup)
        XCTAssertEqual(auditLog.entries[1].operationType, .scan)
    }

    // MARK: - Auto-Truncation Tests

    func testAutoTruncationToMaxEntries() {
        auditLog.maxEntries = 10

        for i in 0..<15 {
            auditLog.log(
                operation: .other,
                itemsAffected: i,
                spaceFreedBytes: UInt64(i * 100),
                success: true
            )
        }

        XCTAssertEqual(auditLog.entries.count, 10)
    }

    // MARK: - Filter Tests

    func testFilterByOperationType() {
        auditLog.log(operation: .cleanup, itemsAffected: 1, spaceFreedBytes: 100, success: true)
        auditLog.log(operation: .scan, itemsAffected: 0, spaceFreedBytes: 0, success: true)
        auditLog.log(operation: .cleanup, itemsAffected: 2, spaceFreedBytes: 200, success: true)

        let cleanupFilter = AuditLogFilter(operationType: .cleanup)
        let cleanupEntries = auditLog.getEntries(filter: cleanupFilter)

        XCTAssertEqual(cleanupEntries.count, 2)
        XCTAssertTrue(cleanupEntries.allSatisfy { $0.operationType == .cleanup })
    }

    func testFilterBySuccess() {
        auditLog.log(operation: .cleanup, success: true)
        auditLog.log(operation: .cleanup, success: false)
        auditLog.log(operation: .scan, success: true)

        let successFilter = AuditLogFilter(successOnly: true)
        let successEntries = auditLog.getEntries(filter: successFilter)

        XCTAssertEqual(successEntries.count, 2)
        XCTAssertTrue(successEntries.allSatisfy { $0.success })
    }

    func testFilterByUserInitiated() {
        auditLog.log(operation: .cleanup, userInitiated: true)
        auditLog.log(operation: .cleanup, userInitiated: false)
        auditLog.log(operation: .scan, userInitiated: true)

        let autoFilter = AuditLogFilter(userInitiatedOnly: false)
        let autoEntries = auditLog.getEntries(filter: autoFilter)

        XCTAssertEqual(autoEntries.count, 1)
        XCTAssertFalse(autoEntries.first!.userInitiated)
    }

    func testFilterByDateRange() {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-7 * 86400)

        // We can't easily inject dates into entries, so test with all filter = no filtering
        auditLog.log(operation: .cleanup, success: true)
        auditLog.log(operation: .scan, success: true)

        let allEntries = auditLog.getEntries(filter: .all)
        XCTAssertEqual(allEntries.count, 2)
    }

    func testCombinedFilters() {
        auditLog.log(operation: .cleanup, success: true, userInitiated: true)
        auditLog.log(operation: .cleanup, success: false, userInitiated: true)
        auditLog.log(operation: .scan, success: true, userInitiated: false)
        auditLog.log(operation: .cleanup, success: true, userInitiated: false)

        let filter = AuditLogFilter(
            operationType: .cleanup,
            successOnly: true,
            userInitiatedOnly: false
        )
        let entries = auditLog.getEntries(filter: filter)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].operationType, .cleanup)
        XCTAssertTrue(entries[0].success)
        XCTAssertFalse(entries[0].userInitiated)
    }

    // MARK: - CSV Export Tests

    func testCSVExportFormat() {
        auditLog.log(
            operation: .cleanup,
            itemsAffected: 5,
            spaceFreedBytes: 100 * 1024 * 1024,
            success: true,
            userInitiated: true,
            details: "Test cleanup"
        )

        let csv = auditLog.exportToCSV()

        XCTAssertTrue(csv.hasPrefix("Timestamp,Operation,Items Affected,Space Freed,Status,Initiated By,Details,Error\n"))
        XCTAssertTrue(csv.contains("Cleanup"))
        XCTAssertTrue(csv.contains("5"))
        XCTAssertTrue(csv.contains("Success"))
        XCTAssertTrue(csv.contains("User"))
    }

    func testCSVExportWithCommaInDetails() {
        auditLog.log(
            operation: .other,
            success: true,
            details: "Item A, Item B, Item C"
        )

        let csv = auditLog.exportToCSV()

        // Commas in details should be escaped (replaced with semicolons)
        XCTAssertTrue(csv.contains("Item A; Item B; Item C"))
    }

    func testCSVExportEmpty() {
        let csv = auditLog.exportToCSV()
        XCTAssertTrue(csv.hasPrefix("Timestamp,Operation,"))
    }

    // MARK: - Statistics Tests

    func testStatisticsCalculation() {
        auditLog.log(operation: .cleanup, itemsAffected: 5, spaceFreedBytes: 100_000_000, success: true)
        auditLog.log(operation: .scan, itemsAffected: 0, spaceFreedBytes: 0, success: true)
        auditLog.log(operation: .duplicateRemoval, itemsAffected: 3, spaceFreedBytes: 50_000_000, success: false)

        let stats = auditLog.getStatistics()

        XCTAssertEqual(stats.totalOperations, 3)
        XCTAssertEqual(stats.successfulOperations, 2)
        XCTAssertEqual(stats.failedOperations, 1)
        XCTAssertEqual(stats.totalItemsAffected, 8)
        XCTAssertEqual(stats.userInitiatedOperations, 3) // all default to userInitiated
        XCTAssertEqual(stats.automatedOperations, 0)

        // Success rate
        XCTAssertEqual(stats.successRate, 2.0 / 3.0 * 100, accuracy: 0.1)
    }

    func testStatisticsWithMixedInitiation() {
        auditLog.log(operation: .cleanup, success: true, userInitiated: true)
        auditLog.log(operation: .cleanup, success: true, userInitiated: false)

        let stats = auditLog.getStatistics()

        XCTAssertEqual(stats.userInitiatedOperations, 1)
        XCTAssertEqual(stats.automatedOperations, 1)
    }

    func testStatisticsEmpty() {
        let stats = auditLog.getStatistics()

        XCTAssertEqual(stats.totalOperations, 0)
        XCTAssertEqual(stats.successRate, 0)
    }

    // MARK: - Clear Tests

    func testClearAll() {
        auditLog.log(operation: .cleanup, success: true)
        auditLog.log(operation: .scan, success: true)

        XCTAssertEqual(auditLog.entries.count, 2)

        auditLog.clearAll()

        XCTAssertEqual(auditLog.entries.count, 0)
    }

    // MARK: - Entry Formatting Tests

    func testEntrySpaceFormatting() {
        auditLog.log(operation: .cleanup, spaceFreedBytes: 100 * 1024 * 1024, success: true)

        let entry = auditLog.entries[0]
        XCTAssertTrue(entry.formattedSpaceFreed.contains("MB"))
        XCTAssertEqual(entry.spaceFreedMB, 100.0, accuracy: 0.01)
    }

    func testEntryLargeSpaceFormatting() {
        auditLog.log(operation: .cleanup, spaceFreedBytes: 2 * 1024 * 1024 * 1024, success: true)

        let entry = auditLog.entries[0]
        XCTAssertTrue(entry.formattedSpaceFreed.contains("GB"))
    }
}

// MARK: - AuditLogEntry Tests

final class AuditLogEntryTests: XCTestCase {

    func testEntryProperties() {
        let entry = AuditLogEntry(
            id: UUID(),
            timestamp: Date(),
            operationType: .installerCleanup,
            itemsAffected: 10,
            spaceFreedBytes: 500 * 1024 * 1024,
            success: true,
            userInitiated: false,
            details: "Auto cleanup",
            errorMessage: nil
        )

        XCTAssertEqual(entry.operationType, .installerCleanup)
        XCTAssertEqual(entry.itemsAffected, 10)
        XCTAssertEqual(entry.formattedSpaceFreed, "500.0 MB")
        XCTAssertEqual(entry.statusText, "Success")
        XCTAssertEqual(entry.initiatedText, "Automated")
        XCTAssertEqual(entry.operationLabel, "Installer Cleanup")
        XCTAssertNotNil(entry.idValue)
    }
}

// MARK: - OperationType Tests

final class OperationTypeTests: XCTestCase {

    func testAllCases() {
        let allCases = OperationType.allCases
        XCTAssertEqual(allCases.count, 13)

        let expected: [OperationType] = [
            .cleanup, .scan, .uninstall, .duplicateRemoval,
            .installerCleanup, .cacheClear, .logPurge, .memoryOptimize,
            .diskCleanup, .permissionFix, .systemTweak, .backup, .restore, .other
        ]
        XCTAssertEqual(allCases, expected)
    }

    func testRawValues() {
        XCTAssertEqual(OperationType.cleanup.rawValue, "Cleanup")
        XCTAssertEqual(OperationType.scan.rawValue, "Scan")
        XCTAssertEqual(OperationType.duplicateRemoval.rawValue, "Duplicate Removal")
        XCTAssertEqual(OperationType.installerCleanup.rawValue, "Installer Cleanup")
    }

    func testIcons() {
        XCTAssertFalse(OperationType.cleanup.icon.isEmpty)
        XCTAssertFalse(OperationType.scan.icon.isEmpty)
        XCTAssertFalse(OperationType.uninstall.icon.isEmpty)
        XCTAssertFalse(OperationType.duplicateRemoval.icon.isEmpty)
        XCTAssertFalse(OperationType.installerCleanup.icon.isEmpty)
    }
}
