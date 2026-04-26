//
//  InstallerEngineTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class InstallerEngineTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PulseInstallerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testScan_FindsOldInstallerArchive() throws {
        let file = tempDir.appendingPathComponent("Cursor.dmg")
        try Data(repeating: 0, count: 120 * 1024 * 1024).write(to: file)
        let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file.path)

        let plan = InstallerEngine(scanRoots: [tempDir.path], minAgeDays: 14, minSizeMB: 100).scan()
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items[0].profile, .installers)
        XCTAssertEqual(plan.items[0].name, "Cursor.dmg")
    }

    func testScan_SkipsRecentInstallerArchive() throws {
        let file = tempDir.appendingPathComponent("Claude.pkg")
        try Data(repeating: 0, count: 120 * 1024 * 1024).write(to: file)
        let recent = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        try FileManager.default.setAttributes([.modificationDate: recent], ofItemAtPath: file.path)

        let plan = InstallerEngine(scanRoots: [tempDir.path], minAgeDays: 14, minSizeMB: 100).scan()
        XCTAssertEqual(plan.items.count, 0)
    }
}
