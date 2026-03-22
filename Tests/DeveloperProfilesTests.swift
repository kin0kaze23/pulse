import XCTest
@testable import Pulse

final class DeveloperProfilesTests: XCTestCase {
    
    // MARK: - Profile Model Tests
    
    func testProfileCategoriesExist() {
        // Verify all profile categories exist
        let categories: [DeveloperProfile.Category] = [
            .appleTools, .containers, .languages, .editors, .packageManagers, .versionControl, .custom
        ]
        XCTAssertEqual(categories.count, 7)
    }
    
    func testBuiltinProfilesCount() {
        // Verify we have all 10 built-in profiles
        XCTAssertEqual(BuiltinProfiles.all.count, 10)
    }
    
    func testBuiltinProfilesHaveRequiredFields() {
        // Verify all built-in profiles have required fields
        for profile in BuiltinProfiles.all {
            XCTAssertFalse(profile.id.isEmpty)
            XCTAssertFalse(profile.name.isEmpty)
            XCTAssertFalse(profile.icon.isEmpty)
            XCTAssertFalse(profile.description.isEmpty)
        }
    }
    
    // MARK: - Disk Scan Tests
    
    func testDiskScanModel() {
        // Verify disk scan model works correctly
        let scan = DeveloperProfile.DiskScan(
            label: "Test",
            path: "~/Test",
            maxDepth: 2,
            safeToDelete: true,
            warningMessage: nil
        )
        
        XCTAssertEqual(scan.label, "Test")
        XCTAssertEqual(scan.path, "~/Test")
        XCTAssertEqual(scan.maxDepth, 2)
        XCTAssertTrue(scan.safeToDelete)
        XCTAssertNil(scan.warningMessage)
    }
    
    // MARK: - Cleanup Action Tests
    
    func testCleanupActionModel() {
        // Verify cleanup action model works correctly
        let action = DeveloperProfile.CleanupAction(
            label: "Test Action",
            shellCommand: "echo test",
            safetyLevel: .safe,
            estimatedSavingsHint: "100 MB",
            requiresConfirmation: false
        )
        
        XCTAssertEqual(action.label, "Test Action")
        XCTAssertEqual(action.shellCommand, "echo test")
        XCTAssertEqual(action.safetyLevel, .safe)
        XCTAssertEqual(action.estimatedSavingsHint, "100 MB")
        XCTAssertFalse(action.requiresConfirmation)
    }
    
    func testSafetyLevelOrdering() {
        // Verify safety levels exist
        let levels: [DeveloperProfile.CleanupAction.SafetyLevel] = [.safe, .moderate, .destructive]
        XCTAssertEqual(levels.count, 3)
    }
    
    // MARK: - Detect Method Tests
    
    func testDetectMethodTypes() {
        // Verify detect methods work correctly
        // These are enum cases, so we just verify they compile
        let _ = DeveloperProfile.DetectMethod.always
        let _ = DeveloperProfile.DetectMethod.processName("test")
        let _ = DeveloperProfile.DetectMethod.bundleID("com.test")
        let _ = DeveloperProfile.DetectMethod.commandExists("test")
        let _ = DeveloperProfile.DetectMethod.directoryExists("~/test")
    }
}