import XCTest
@testable import PulseApp

final class PermissionsAuditServiceTests: XCTestCase {

    var service: PermissionsAuditService!

    override func setUp() {
        super.setUp()
        service = PermissionsAuditService.shared
    }

    // MARK: - FDA Status Tests

    func testFDAStatusNotRequestedInitially() {
        // Initial state should be notRequested or granted/denied depending on system
        let status = service.fdaStatus
        XCTAssertTrue(
            status == .notRequested ||
            status == .granted ||
            status == .denied
        )
    }

    func testFDAStatusDescriptions() {
        XCTAssertEqual(FDARequestState.notRequested.description, "Full Disk Access not granted")
        XCTAssertEqual(FDARequestState.requesting.description, "Requesting access...")
        XCTAssertEqual(FDARequestState.granted.description, "Full Disk Access granted")
        XCTAssertEqual(FDARequestState.denied.description, "Access denied - please grant manually")
        XCTAssertEqual(FDARequestState.openSettings.description, "Open System Settings to grant access")
    }

    // MARK: - Permission Info Type Tests

    func testPermissionInfoTypeAllCases() {
        XCTAssertEqual(PermissionInfoType.allCases.count, 11)
    }

    func testPermissionInfoTypeDisplayNames() {
        for type in PermissionInfoType.allCases {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testPermissionInfoTypeIcons() {
        for type in PermissionInfoType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    // MARK: - Permission Status Tests

    func testPermissionStatusColors() {
        XCTAssertEqual(PermissionStatus.granted.color, "green")
        XCTAssertEqual(PermissionStatus.missing.color, "orange")
        XCTAssertEqual(PermissionStatus.unknown.color, "gray")
        XCTAssertEqual(PermissionStatus.verificationPending.color, "yellow")
    }

    func testPermissionStatusIcons() {
        XCTAssertEqual(PermissionStatus.granted.icon, "checkmark.circle.fill")
        XCTAssertEqual(PermissionStatus.missing.icon, "exclamationmark.triangle.fill")
    }

    func testPermissionStatusBooleans() {
        XCTAssertTrue(PermissionStatus.granted.isGranted)
        XCTAssertFalse(PermissionStatus.granted.isMissing)

        XCTAssertTrue(PermissionStatus.missing.isMissing)
        XCTAssertFalse(PermissionStatus.missing.isGranted)
    }

    // MARK: - Permission Type Tests

    func testPermissionTypeAllCases() {
        XCTAssertEqual(PermissionType.allCases.count, 4)
    }

    func testPermissionTypeIdentifiers() {
        XCTAssertEqual(PermissionType.fullDiskAccess.identifier, "full-disk-access")
        XCTAssertEqual(PermissionType.accessibility.identifier, "accessibility")
        XCTAssertEqual(PermissionType.notifications.identifier, "notifications")
        XCTAssertEqual(PermissionType.appleEvents.identifier, "apple-events")
    }

    // MARK: - Service State Tests

    func testServiceInitialState() {
        XCTAssertFalse(service.isScanning)
        XCTAssertEqual(service.scanProgress, "Ready")
    }

    // MARK: - App Permissions Tests

    func testAppPermissionsStartsEmpty() {
        // Should start empty before scan
        XCTAssertTrue(service.appPermissions.isEmpty)
    }

    // MARK: - FDA Request State Equality

    func testFDARequestStateEquality() {
        XCTAssertEqual(FDARequestState.notRequested, .notRequested)
        XCTAssertEqual(FDARequestState.granted, .granted)
        XCTAssertNotEqual(FDARequestState.granted, .denied)
    }
}