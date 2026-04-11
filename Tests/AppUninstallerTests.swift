//
//  AppUninstallerTests.swift
//  PulseTests
//
//  Unit tests for the AppUninstaller service.
//  Tests focus on safety, exact path matching, and protection logic.
//

import XCTest
@testable import Pulse

@MainActor
final class AppUninstallerTests: XCTestCase {

    // MARK: - Protected Apps

    func testProtectedBundleIdentifiers() {
        let protected = AppUninstaller.protectedBundleIdentifiers

        // Core system apps must be protected
        XCTAssertTrue(protected.contains("com.apple.finder"))
        XCTAssertTrue(protected.contains("com.apple.dock"))
        XCTAssertTrue(protected.contains("com.apple.Safari"))
        XCTAssertTrue(protected.contains("com.apple.mail"))

        // Pulse itself must be protected
        XCTAssertTrue(
            protected.contains("com.jonathannugroho.Pulse") ||
            protected.contains("com.nousresearch.Pulse")
        )
    }

    func testProtectedAppNames() {
        let protected = AppUninstaller.protectedAppNames

        XCTAssertTrue(protected.contains("Finder"))
        XCTAssertTrue(protected.contains("Dock"))
        XCTAssertTrue(protected.contains("Safari"))
        XCTAssertTrue(protected.contains("Mail"))
        XCTAssertTrue(protected.contains("Pulse"))
    }

    func testIsProtectedSystemApps() {
        let uninstaller = AppUninstaller()

        // Test that system app detection works for /System paths
        let systemApp = InstalledApp(
            bundleIdentifier: "com.apple.some.system.app",
            appName: "SystemApp",
            appURL: URL(fileURLWithPath: "/System/Applications/Utility.app"),
            version: "1.0",
            fileSizeBytes: 1000
        )
        XCTAssertTrue(uninstaller.isProtected(systemApp))
    }

    func testIsNotProtectedThirdPartyApp() {
        let uninstaller = AppUninstaller()

        let thirdPartyApp = InstalledApp(
            bundleIdentifier: "com.example.myapp",
            appName: "MyApp",
            appURL: URL(fileURLWithPath: "/Applications/MyApp.app"),
            version: "1.0",
            fileSizeBytes: 50_000_000
        )
        XCTAssertFalse(uninstaller.isProtected(thirdPartyApp))
    }

    // MARK: - Path Safety

    func testPathSafetyRejectsSystemPaths() {
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/System/Library"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/bin/bash"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/usr/bin"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/Library/LaunchDaemons"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/dev/null"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/private/etc"))
    }

    func testPathSafetyRejectsUserFolders() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("\(home)/Documents"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("\(home)/Desktop"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("\(home)/Downloads"))
    }

    func testPathSafetyAllowsLibraryPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Library subpaths should be allowed
        XCTAssertTrue(AppUninstaller.isPathSafeToDelete("\(home)/Library/Caches/com.example.app"))
        XCTAssertTrue(AppUninstaller.isPathSafeToDelete("\(home)/Library/Application Support/com.example.app"))
        XCTAssertTrue(AppUninstaller.isPathSafeToDelete("\(home)/Library/Preferences/com.example.app.plist"))
        XCTAssertTrue(AppUninstaller.isPathSafeToDelete("\(home)/Library/Containers/com.example.app"))
        XCTAssertTrue(AppUninstaller.isPathSafeToDelete("\(home)/Library/Logs/com.example.app"))
    }

    func testPathSafetyRejectsAppBundlePaths() {
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/Applications/SomeApp.app"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("/Users/test/MyApp.app"))
        XCTAssertFalse(AppUninstaller.isPathSafeToDelete("~/SomeApp.app"))
    }

    // MARK: - Exact Path Matching (Critical: No Fuzzy Logic)

    func testAssociatedFilesUseExactPaths() {
        let uninstaller = AppUninstaller()

        // Create a test app
        let testApp = InstalledApp(
            bundleIdentifier: "com.example.testapp",
            appName: "TestApp",
            appURL: URL(fileURLWithPath: "/Applications/TestApp.app"),
            version: "1.0",
            fileSizeBytes: 1000
        )

        let files = uninstaller.findAssociatedFiles(for: testApp)

        // Every returned file must be an EXACT path match
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let bundleID = "com.example.testapp"

        let allowedExactPaths: Set<String> = [
            "\(home)/Library/Application Support/\(bundleID)",
            "\(home)/Library/Containers/\(bundleID)",
            "\(home)/Library/Caches/\(bundleID)",
            "\(home)/Library/Preferences/\(bundleID).plist",
            "\(home)/Library/Saved Application State/\(bundleID).savedState",
            "\(home)/Library/Logs/\(bundleID)",
        ]

        for file in files {
            let isAllowedPath = allowedExactPaths.contains(file.path)
            let isGroupContainer = file.type == .groupContainers && file.path.contains("Group Containers")

            XCTAssertTrue(
                isAllowedPath || isGroupContainer,
                "File path '\(file.path)' is not an allowed exact path. Type: \(file.type)"
            )
        }

        // Verify NO files from dangerous locations
        for file in files {
            XCTAssertFalse(file.path.contains("/Documents/"), "Must not include Documents files")
            XCTAssertFalse(file.path.contains("/Desktop/"), "Must not include Desktop files")
            XCTAssertFalse(file.path.contains("/Downloads/"), "Must not include Downloads files")
        }
    }

    func testNoPatternMatchingInPathDetection() {
        // This test verifies that the findAssociatedFiles method
        // does NOT use glob patterns, wildcards, or fuzzy matching.
        // It can ONLY check exact paths.
        //
        // We verify this by checking that a non-existent bundle ID
        // returns zero files (no false positives from pattern matching)
        let uninstaller = AppUninstaller()

        let fakeApp = InstalledApp(
            bundleIdentifier: "com.totally.fake.app.that.does.not.exist.xyz123",
            appName: "FakeApp",
            appURL: URL(fileURLWithPath: "/tmp/FakeApp.app"),
            version: nil,
            fileSizeBytes: 0
        )

        let files = uninstaller.findAssociatedFiles(for: fakeApp)

        // Should be empty since these exact paths don't exist
        // If pattern matching was used, we might get false positives
        XCTAssertTrue(
            files.isEmpty,
            "Non-existent app should have zero associated files (verifies no pattern matching)"
        )
    }

    // MARK: - Preview Creation

    func testPreviewCreation() {
        let uninstaller = AppUninstaller()

        let testApp = InstalledApp(
            bundleIdentifier: "com.example.previewapp",
            appName: "PreviewApp",
            appURL: URL(fileURLWithPath: "/Applications/PreviewApp.app"),
            version: "2.0",
            fileSizeBytes: 100_000_000 // 100 MB
        )

        let preview = uninstaller.createPreview(for: testApp)

        XCTAssertEqual(preview.app.bundleIdentifier, testApp.bundleIdentifier)
        XCTAssertEqual(preview.app.appName, testApp.appName)
        XCTAssertGreaterThanOrEqual(preview.totalSizeBytes, testApp.fileSizeBytes)
        XCTAssertTrue(preview.itemCount >= 1) // At least the app bundle
    }

    func testPreviewIncludesAppSize() {
        let uninstaller = AppUninstaller()

        let testApp = InstalledApp(
            bundleIdentifier: "com.example.sizeapp",
            appName: "SizeApp",
            appURL: URL(fileURLWithPath: "/Applications/SizeApp.app"),
            version: nil,
            fileSizeBytes: 50_000_000
        )

        let preview = uninstaller.createPreview(for: testApp)

        // Total size should be at least the app size
        XCTAssertGreaterThanOrEqual(preview.totalSizeBytes, 50_000_000)
    }

    // MARK: - InstalledApp

    func testInstalledAppFileSizeFormatting() {
        let smallApp = InstalledApp(
            bundleIdentifier: "com.example.small",
            appName: "SmallApp",
            appURL: URL(fileURLWithPath: "/Applications/SmallApp.app"),
            version: nil,
            fileSizeBytes: 1024
        )
        XCTAssertTrue(smallApp.fileSizeText.contains("KB") || smallApp.fileSizeText.contains("kB"))

        let largeApp = InstalledApp(
            bundleIdentifier: "com.example.large",
            appName: "LargeApp",
            appURL: URL(fileURLWithPath: "/Applications/LargeApp.app"),
            version: nil,
            fileSizeBytes: 1_000_000_000
        )
        XCTAssertTrue(largeApp.fileSizeText.contains("GB"))
    }

    func testInstalledAppEquality() {
        let app1 = InstalledApp(
            bundleIdentifier: "com.example.app",
            appName: "App",
            appURL: URL(fileURLWithPath: "/Applications/App.app"),
            version: nil,
            fileSizeBytes: 0
        )

        let app2 = InstalledApp(
            bundleIdentifier: "com.example.app",
            appName: "Different Name",
            appURL: URL(fileURLWithPath: "/Applications/App.app"),
            version: "1.0",
            fileSizeBytes: 1000
        )

        // Apps are equal if bundle identifiers match
        XCTAssertEqual(app1, app2)
    }

    // MARK: - Associated File

    func testAssociatedFileSizeMB() {
        let file = AssociatedFile(
            path: "/test/path",
            type: .caches,
            sizeBytes: 10 * 1024 * 1024 // 10 MB
        )
        XCTAssertEqual(file.sizeMB, 10.0, accuracy: 0.01)
    }

    func testAssociatedFileTypeIcons() {
        XCTAssertEqual(AssociatedFileType.applicationSupport.icon, "folder.fill.badge.gearshape")
        XCTAssertEqual(AssociatedFileType.containers.icon, "app.badge")
        XCTAssertEqual(AssociatedFileType.groupContainers.icon, "rectangle.on.rectangle")
        XCTAssertEqual(AssociatedFileType.caches.icon, "wind")
        XCTAssertEqual(AssociatedFileType.preferences.icon, "gearshape.fill")
        XCTAssertEqual(AssociatedFileType.savedState.icon, "clock.arrow.circlepath")
        XCTAssertEqual(AssociatedFileType.logs.icon, "doc.text.fill")
    }

    // MARK: - UninstallPreview

    func testUninstallPreviewCannotUninstallRunningApp() {
        let testApp = InstalledApp(
            bundleIdentifier: "com.example.runningapp",
            appName: "RunningApp",
            appURL: URL(fileURLWithPath: "/Applications/RunningApp.app"),
            version: nil,
            fileSizeBytes: 0
        )

        let preview = UninstallPreview(
            app: testApp,
            appIsRunning: true,
            associatedFiles: [],
            totalSizeBytes: 0
        )

        XCTAssertFalse(preview.canUninstall)
    }

    func testUninstallPreviewCanUninstallStoppedApp() {
        let testApp = InstalledApp(
            bundleIdentifier: "com.example.stoppedapp",
            appName: "StoppedApp",
            appURL: URL(fileURLWithPath: "/Applications/StoppedApp.app"),
            version: nil,
            fileSizeBytes: 0
        )

        let preview = UninstallPreview(
            app: testApp,
            appIsRunning: false,
            associatedFiles: [],
            totalSizeBytes: 0
        )

        XCTAssertTrue(preview.canUninstall)
    }

    func testUninstallPreviewItemCount() {
        let testApp = InstalledApp(
            bundleIdentifier: "com.example.countapp",
            appName: "CountApp",
            appURL: URL(fileURLWithPath: "/Applications/CountApp.app"),
            version: nil,
            fileSizeBytes: 0
        )

        let files = [
            AssociatedFile(path: "/path/1", type: .caches, sizeBytes: 100),
            AssociatedFile(path: "/path/2", type: .logs, sizeBytes: 200),
        ]

        let preview = UninstallPreview(
            app: testApp,
            appIsRunning: false,
            associatedFiles: files,
            totalSizeBytes: 300
        )

        XCTAssertEqual(preview.itemCount, 3) // 1 app + 2 files
    }

    // MARK: - UninstallResult

    func testUninstallResultSuccessSummary() {
        let result = UninstallResult(
            success: true,
            appRemoved: true,
            filesRemoved: 5,
            filesFailed: 0,
            errorMessage: nil
        )

        XCTAssertTrue(result.summary.contains("Successfully"))
        XCTAssertTrue(result.summary.contains("5"))
    }

    func testUninstallResultFailureSummary() {
        let result = UninstallResult(
            success: false,
            appRemoved: false,
            filesRemoved: 0,
            filesFailed: 0,
            errorMessage: "App is protected"
        )

        XCTAssertTrue(result.summary.contains("failed"))
        XCTAssertTrue(result.summary.contains("protected"))
    }

    // MARK: - Size Calculation

    func testSizeOfNonExistentPath() {
        XCTAssertEqual(AppUninstaller.sizeOfPath("/nonexistent/path/xyz123"), 0)
    }

    func testSizeOfExistingFile() {
        // Create a temp file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PulseUninstallTest_\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Create a test file
            let testFile = tempDir.appendingPathComponent("test.dat")
            let data = Data(repeating: 0, count: 1024)
            try data.write(to: testFile)

            let size = AppUninstaller.sizeOfPath(testFile.path)
            XCTAssertGreaterThanOrEqual(size, 1024)

            // Cleanup
            try FileManager.default.removeItem(at: tempDir)
        } catch {
            XCTFail("Failed to create test directory: \(error)")
        }
    }
}
