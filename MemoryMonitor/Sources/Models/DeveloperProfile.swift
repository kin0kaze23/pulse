import SwiftUI

struct DeveloperProfile: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let category: Category
    let detectMethod: DetectMethod
    let memoryProcessPatterns: [String]
    let diskScans: [DiskScan]
    let cleanupActions: [CleanupAction]
    let description: String

    enum Category: String, CaseIterable {
        case appleTools      = "Apple Tools"
        case containers      = "Containers"
        case languages       = "Languages"
        case editors         = "Editors"
        case packageManagers = "Package Managers"
        case versionControl  = "Version Control"
        case custom          = "Custom"
    }

    enum DetectMethod {
        case processName(String)      // Check via ps/pgrep
        case bundleID(String)         // NSWorkspace.runningApplications
        case commandExists(String)    // `which <cmd>` returns 0
        case directoryExists(String)  // FileManager.fileExists
        case always                   // Always show (e.g., system-level)
    }

    struct DiskScan: Identifiable {
        let id = UUID()
        let label: String
        let path: String              // Supports ~ expansion
        let maxDepth: Int
        let safeToDelete: Bool
        let warningMessage: String?
    }

    struct CleanupAction: Identifiable {
        let id = UUID()
        let label: String
        let shellCommand: String
        let safetyLevel: SafetyLevel
        let estimatedSavingsHint: String?
        let requiresConfirmation: Bool

        enum SafetyLevel {
            case safe           // Green — no data loss possible
            case moderate       // Orange — rebuilds automatically
            case destructive    // Red — data cannot be recovered
        }
    }
}