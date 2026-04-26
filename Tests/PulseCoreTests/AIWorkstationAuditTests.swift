//
//  AIWorkstationAuditTests.swift
//  PulseCoreTests
//

import XCTest
@testable import PulseCore

final class AIWorkstationAuditTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PulseAIAuditTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testIndexBloatAudit_DoesNotCrash() {
        let issues = IndexBloatAuditScanner().scan(config: PulseConfig())
        XCTAssertGreaterThanOrEqual(issues.count, 0)
    }

    func testAgentDataAudit_DoesNotCrash() {
        let issues = AgentDataAuditScanner().scan()
        XCTAssertGreaterThanOrEqual(issues.count, 0)
    }

    func testModelsAudit_DoesNotCrash() {
        let issues = ModelsAuditScanner().scan()
        XCTAssertGreaterThanOrEqual(issues.count, 0)
    }

    func testIndexBloatAudit_SuggestsCursorIgnorePatterns() throws {
        let project = tempDir.appendingPathComponent("ai-repo")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: project.appendingPathComponent("package.json"))

        let nodeModules = project.appendingPathComponent("node_modules")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 60 * 1024 * 1024).write(to: nodeModules.appendingPathComponent("blob.bin"))

        let nextDir = project.appendingPathComponent(".next")
        try FileManager.default.createDirectory(at: nextDir, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 60 * 1024 * 1024).write(to: nextDir.appendingPathComponent("blob.bin"))

        let config = PulseConfig(artifactScanPaths: [tempDir.path])
        let issues = IndexBloatAuditScanner().scan(config: config)

        XCTAssertEqual(issues.count, 1)
        let description = issues[0].description
        XCTAssertTrue(description.contains("Suggested .cursorignore"))
        XCTAssertTrue(description.contains("node_modules"))
        XCTAssertTrue(description.contains(".next"))
        XCTAssertTrue(description.contains("files.watcherExclude"))
    }
}
