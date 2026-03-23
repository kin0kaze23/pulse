import XCTest
@testable import Pulse

final class DirectorySizeUtilityTests: XCTestCase {
    
    // MARK: - Test Known Directories
    
    func testHomeDirectoryExists() {
        let homePath = NSHomeDirectory()
        let size = DirectorySizeUtility.directorySizeBytes(homePath)
        // Home directory should have some content
        XCTAssertGreaterThan(size, 0, "Home directory should have some size")
    }
    
    func testNonExistentDirectory() {
        let size = DirectorySizeUtility.directorySizeBytes("/nonexistent/path/that/does/not/exist")
        XCTAssertEqual(size, 0, "Non-existent directory should return 0")
    }
    
    func testDirectorySizeMB() {
        let homePath = NSHomeDirectory()
        let sizeMB = DirectorySizeUtility.directorySizeMB(homePath)
        // Home directory should have at least 1 MB
        XCTAssertGreaterThan(sizeMB, 1.0, "Home directory should be at least 1 MB")
    }
    
    func testDirectorySizeGB() {
        let homePath = NSHomeDirectory()
        let sizeGB = DirectorySizeUtility.directorySizeGB(homePath)
        let sizeMB = DirectorySizeUtility.directorySizeMB(homePath)
        // GB should be MB / 1024
        XCTAssertEqual(sizeGB, sizeMB / 1024, accuracy: 0.01, "GB conversion should match")
    }
    
    // MARK: - Test Quick Size Estimation
    
    func testQuickSizeEstimation() {
        let homePath = NSHomeDirectory()
        let quickSize = DirectorySizeUtility.quickDirectorySizeMB(homePath, maxItems: 100)
        // Quick size with low limit should return something
        XCTAssertGreaterThanOrEqual(quickSize, 0, "Quick size should return a non-negative value")
    }
    
    func testQuickSizeWithNonExistentPath() {
        let quickSize = DirectorySizeUtility.quickDirectorySizeMB("/nonexistent/path", maxItems: 100)
        XCTAssertEqual(quickSize, 0, "Quick size of non-existent path should be 0")
    }
    
    // MARK: - Test Tilde Expansion
    
    func testTildeExpansion() {
        let path = "~/Desktop"
        let expanded = path.expandingTilde
        XCTAssertTrue(expanded.contains("/Users/"), "Tilde should expand to user home")
        XCTAssertFalse(expanded.contains("~"), "Expanded path should not contain tilde")
    }
    
    // MARK: - Test Size Consistency
    
    func testSizeConsistency() {
        // Test that multiple calls return consistent results
        let libraryPath = "~/Library".expandingTilde
        let size1 = DirectorySizeUtility.directorySizeMB(libraryPath)
        let size2 = DirectorySizeUtility.directorySizeMB(libraryPath)
        
        XCTAssertEqual(size1, size2, accuracy: 0.01, "Multiple calls should return same size")
    }
    
    // MARK: - Test Small Directories
    
    func testSmallDirectory() {
        // Create a temp directory with known content
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PulseTest_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Create a small file
            let testFile = tempDir.appendingPathComponent("test.txt")
            let testData = "Hello World".data(using: .utf8)!
            try testData.write(to: testFile)
            
            let sizeBytes = DirectorySizeUtility.directorySizeBytes(tempDir.path)
            let expectedSize = UInt64(testData.count)
            
            XCTAssertEqual(sizeBytes, expectedSize, "Small directory size should match file size")
            
            // Cleanup
            try FileManager.default.removeItem(at: tempDir)
        } catch {
            XCTFail("Failed to create test directory: \(error)")
        }
    }
}