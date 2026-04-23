//
//  ArtifactScannerTests.swift
//  PulseCoreTests
//
//  Tests for ArtifactScanner — ensures artifact discovery works correctly.
//

import Foundation
@testable import PulseCore
import XCTest

final class ArtifactScannerTests: XCTestCase {
    private var tempDir: URL!
    private var scanner: ArtifactScanner!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PulseArtifactTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        scanner = ArtifactScanner()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helper

    /// Create a fake artifact directory with a given size in MB.
    private func createArtifact(at projectDir: URL, name: String, sizeMB: Int, daysAgo: Int = 30) throws -> URL {
        let artifactDir = projectDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)

        // Create a file of the given size
        let filePath = artifactDir.appendingPathComponent("data.bin")
        let data = Data(repeating: 0, count: sizeMB * 1024 * 1024)
        try data.write(to: filePath)

        // Set modification date
        let modDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        try FileManager.default.setAttributes([.modificationDate: modDate], ofItemAtPath: artifactDir.path)

        return artifactDir
    }

    // MARK: - Tests

    func testScan_EmptyDirectory_ReturnsEmpty() throws {
        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 0,
            minSizeMB: 0
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 0)
    }

    func testScan_NodeModules_Discovered() throws {
        let projectDir = tempDir.appendingPathComponent("my-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try createArtifact(at: projectDir, name: "node_modules", sizeMB: 150, daysAgo: 60)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 30,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(artifacts[0].artifactName, "node_modules")
        XCTAssertEqual(artifacts[0].type.tool, "npm/yarn/pnpm")
        XCTAssertEqual(artifacts[0].sizeMB, 150, accuracy: 1)
    }

    func testScan_MultipleArtifactTypes() throws {
        let appDir = tempDir.appendingPathComponent("my-app")
        let apiDir = tempDir.appendingPathComponent("my-api")
        let libDir = tempDir.appendingPathComponent("my-lib")
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: apiDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: libDir, withIntermediateDirectories: true)

        try createArtifact(at: appDir, name: "node_modules", sizeMB: 200, daysAgo: 90)
        try createArtifact(at: apiDir, name: "target", sizeMB: 300, daysAgo: 120)
        try createArtifact(at: libDir, name: ".build", sizeMB: 150, daysAgo: 60)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 30,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 3)

        // Should be sorted by size descending
        XCTAssertEqual(artifacts[0].artifactName, "target")
        XCTAssertEqual(artifacts[0].sizeMB, 300, accuracy: 1)
        XCTAssertEqual(artifacts[1].artifactName, "node_modules")
        XCTAssertEqual(artifacts[1].sizeMB, 200, accuracy: 1)
        XCTAssertEqual(artifacts[2].artifactName, ".build")
        XCTAssertEqual(artifacts[2].sizeMB, 150, accuracy: 1)
    }

    func testScan_SkipsRecentArtifacts() throws {
        let projectDir = tempDir.appendingPathComponent("my-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try createArtifact(at: projectDir, name: "node_modules", sizeMB: 200, daysAgo: 3)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 7,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertTrue(artifacts[0].isRecent)
    }

    func testScan_SkipsSmallArtifacts() throws {
        let projectDir = tempDir.appendingPathComponent("my-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try createArtifact(at: projectDir, name: "node_modules", sizeMB: 50, daysAgo: 30)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 0,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 0)
    }

    func testScan_RespectsExcludedPaths() throws {
        let excludedDir = tempDir.appendingPathComponent("excluded")
        let includedDir = tempDir.appendingPathComponent("included")
        try FileManager.default.createDirectory(at: excludedDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: includedDir, withIntermediateDirectories: true)

        try createArtifact(at: excludedDir, name: "node_modules", sizeMB: 200, daysAgo: 60)
        try createArtifact(at: includedDir, name: "target", sizeMB: 200, daysAgo: 60)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 0,
            minSizeMB: 100,
            excludedPaths: [excludedDir.path]
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(artifacts[0].artifactName, "target")
    }

    func testScan_AllArtifactTypes() throws {
        let types: [(String, Int)] = [
            ("node_modules", 150),
            (".build", 120),
            ("target", 200),
            ("dist", 180),
            ("build", 110),
            ("venv", 250),
            (".venv", 220),
            ("__pycache__", 130),
            (".dart_tool", 140),
            ("Pods", 300),
        ]

        for (i, pair) in types.enumerated() {
            let projectDir = tempDir.appendingPathComponent("project-\(i)")
            try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
            try createArtifact(at: projectDir, name: pair.0, sizeMB: pair.1, daysAgo: 30 + i)
        }

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 0,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, types.count)

        // Verify each type was discovered
        let foundNames = Set(artifacts.map { $0.artifactName })
        for (name, _) in types {
            XCTAssertTrue(foundNames.contains(name), "Expected to find artifact: \(name)")
        }
    }

    func testPlan_ConvertsArtifactsToCleanupPlan() throws {
        let projectDir = tempDir.appendingPathComponent("my-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try createArtifact(at: projectDir, name: "node_modules", sizeMB: 200, daysAgo: 60)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 30,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 1)

        let plan = scanner.plan(from: artifacts)
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items[0].name, "my-app/node_modules")
        XCTAssertEqual(plan.totalSizeMB, 200, accuracy: 1)
        XCTAssertEqual(plan.items[0].category, .developer)
        XCTAssertNil(plan.items[0].skipReason)
    }

    func testPlan_RecentArtifactsHaveSkipReason() throws {
        let projectDir = tempDir.appendingPathComponent("my-app")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        try createArtifact(at: projectDir, name: "node_modules", sizeMB: 200, daysAgo: 3)

        let config = ArtifactScanConfig(
            scanPaths: [tempDir.path],
            minAgeDays: 7,
            minSizeMB: 100
        )

        let artifacts = scanner.scan(config: config)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertTrue(artifacts[0].isRecent)

        let plan = scanner.plan(from: artifacts)
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertNotNil(plan.items[0].skipReason)
        XCTAssertTrue(plan.items[0].skipReason!.contains("Recently modified"))
    }
}
