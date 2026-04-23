import SwiftUI

enum BuiltinProfiles {
    static let all: [DeveloperProfile] = [
        xcode, docker, node, opencode,
        python, vscode, homebrew, git,
        androidStudio, jetbrains
    ]

    static let xcode = DeveloperProfile(
        id: "xcode",
        name: "Xcode",
        icon: "hammer.fill",
        color: .blue,
        category: .appleTools,
        detectMethod: .bundleID("com.apple.dt.Xcode"),
        memoryProcessPatterns: [
            "XcodeBuildService",
            "swift-frontend",
            "clang",
            "com.apple.dt.SKAgent"
        ],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "DerivedData",
                path: "~/Library/Developer/Xcode/DerivedData",
                maxDepth: 2,
                safeToDelete: true,
                warningMessage: "Xcode will rebuild on next build. Increases first build time."
            ),
            DeveloperProfile.DiskScan(
                label: "Archives",
                path: "~/Library/Developer/Xcode/Archives",
                maxDepth: 2,
                safeToDelete: false,
                warningMessage: "Archives contain your app binaries. Only delete if backed up."
            ),
            DeveloperProfile.DiskScan(
                label: "iOS Device Support",
                path: "~/Library/Developer/Xcode/iOS DeviceSupport",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean DerivedData",
                shellCommand: "rm -rf ~/Library/Developer/Xcode/DerivedData/*",
                safetyLevel: .moderate,
                estimatedSavingsHint: "Usually 1–20 GB",
                requiresConfirmation: true
            ),
            DeveloperProfile.CleanupAction(
                label: "Remove Old Simulators",
                shellCommand: "xcrun simctl delete unavailable",
                safetyLevel: .safe,
                estimatedSavingsHint: "Varies",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Kill Build Daemons",
                shellCommand: "pkill -x XcodeBuildService; pkill -x swift-frontend",
                safetyLevel: .moderate,
                estimatedSavingsHint: "200–800 MB RAM",
                requiresConfirmation: true
            ),
        ],
        description: "Apple's IDE and build system. DerivedData and device support can grow to 30+ GB."
    )

    static let docker = DeveloperProfile(
        id: "docker",
        name: "Docker",
        icon: "cube.box.fill",
        color: .cyan,
        category: .containers,
        detectMethod: .processName("com.docker.backend"),
        memoryProcessPatterns: ["com.docker.backend", "containerd", "docker"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Docker Data",
                path: "~/Library/Containers/com.docker.docker/Data",
                maxDepth: 1,
                safeToDelete: false,
                warningMessage: "Contains all images and containers."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Remove Stopped Containers",
                shellCommand: "/usr/local/bin/docker container prune -f 2>/dev/null || docker container prune -f",
                safetyLevel: .safe,
                estimatedSavingsHint: "Varies",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Remove Dangling Images",
                shellCommand: "/usr/local/bin/docker image prune -f 2>/dev/null || docker image prune -f",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 5 GB",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Full System Prune",
                shellCommand: "/usr/local/bin/docker system prune -f --volumes 2>/dev/null || docker system prune -f --volumes",
                safetyLevel: .destructive,
                estimatedSavingsHint: "1–20 GB",
                requiresConfirmation: true
            ),
        ],
        description: "Container runtime. Unused images and volumes accumulate rapidly."
    )

    static let node = DeveloperProfile(
        id: "node",
        name: "Node / npm",
        icon: "cube.transparent.fill",
        color: .green,
        category: .languages,
        detectMethod: .commandExists("node"),
        memoryProcessPatterns: ["node", "npm"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "npm cache",
                path: "~/.npm",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
            DeveloperProfile.DiskScan(
                label: "yarn cache",
                path: "~/.yarn/cache",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
            DeveloperProfile.DiskScan(
                label: "pnpm store",
                path: "~/.pnpm-store",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean npm cache",
                shellCommand: "npm cache clean --force",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 3 GB",
                requiresConfirmation: false
            ),
            DeveloperProfile.CleanupAction(
                label: "Clean yarn cache",
                shellCommand: "yarn cache clean 2>/dev/null || true",
                safetyLevel: .safe,
                estimatedSavingsHint: "Varies",
                requiresConfirmation: false
            ),
        ],
        description: "JavaScript runtime. npm/yarn caches and node_modules directories grow fast."
    )

    static let opencode = DeveloperProfile(
        id: "opencode",
        name: "OpenCode",
        icon: "terminal.fill",
        color: .purple,
        category: .editors,
        detectMethod: .processName("opencode"),
        memoryProcessPatterns: ["opencode"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "OpenCode DB",
                path: "~/.local/share/opencode/opencode.db",
                maxDepth: 0,
                safeToDelete: false,
                warningMessage: "Contains session history. Vacuum will compact it."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Vacuum DB",
                shellCommand: """
                    sqlite3 ~/.local/share/opencode/opencode.db \
                    "DELETE FROM part WHERE session_id NOT IN \
                    (SELECT id FROM session ORDER BY time_updated DESC LIMIT 3); \
                    DELETE FROM session WHERE id NOT IN \
                    (SELECT id FROM session ORDER BY time_updated DESC LIMIT 3); \
                    VACUUM;"
                    """,
                safetyLevel: .moderate,
                estimatedSavingsHint: "Up to 500 MB",
                requiresConfirmation: true
            ),
            DeveloperProfile.CleanupAction(
                label: "Kill Standalone Sessions",
                shellCommand: "pkill -f 'opencode' || true",
                safetyLevel: .moderate,
                estimatedSavingsHint: "200–800 MB RAM",
                requiresConfirmation: true
            ),
        ],
        description: "AI coding assistant. DB grows with session history; standalone sessions waste RAM."
    )

    static let python = DeveloperProfile(
        id: "python",
        name: "Python",
        icon: "doc.text.fill",
        color: .yellow,
        category: .languages,
        detectMethod: .commandExists("python3"),
        memoryProcessPatterns: ["python", "python3", "jupyter"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "pip cache",
                path: "~/Library/Caches/pip",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean pip cache",
                shellCommand: "pip3 cache purge 2>/dev/null || true",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 2 GB",
                requiresConfirmation: false
            ),
        ],
        description: "Python interpreter. pip cache accumulates downloaded packages."
    )

    static let vscode = DeveloperProfile(
        id: "vscode",
        name: "VS Code",
        icon: "chevron.left.forwardslash.chevron.right",
        color: .blue,
        category: .editors,
        detectMethod: .bundleID("com.microsoft.VSCode"),
        memoryProcessPatterns: ["Electron", "Code Helper"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Extension Cache",
                path: "~/.vscode/extensions",
                maxDepth: 1,
                safeToDelete: false,
                warningMessage: "Contains installed extensions."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clear Workspace Storage",
                shellCommand: "rm -rf ~/Library/Application\\ Support/Code/User/workspaceStorage/*",
                safetyLevel: .moderate,
                estimatedSavingsHint: "100 MB – 1 GB",
                requiresConfirmation: true
            ),
        ],
        description: "Electron-based editor. Workspace storage and extension caches accumulate over time."
    )

    static let homebrew = DeveloperProfile(
        id: "homebrew",
        name: "Homebrew",
        icon: "flask.fill",
        color: .orange,
        category: .packageManagers,
        detectMethod: .commandExists("brew"),
        memoryProcessPatterns: [],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Homebrew Cache",
                path: "~/Library/Caches/Homebrew",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "brew cleanup",
                shellCommand: "/opt/homebrew/bin/brew cleanup --prune=all 2>/dev/null || /usr/local/bin/brew cleanup --prune=all 2>/dev/null || true",
                safetyLevel: .safe,
                estimatedSavingsHint: "100 MB – 5 GB",
                requiresConfirmation: false
            ),
        ],
        description: "macOS package manager. Old formula versions and downloads pile up."
    )

    static let git = DeveloperProfile(
        id: "git",
        name: "Git",
        icon: "arrow.triangle.branch",
        color: .red,
        category: .versionControl,
        detectMethod: .commandExists("git"),
        memoryProcessPatterns: ["git"],
        diskScans: [],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "GC all repos in ~/Projects",
                shellCommand: """
                    find ~/Projects -maxdepth 3 -name ".git" -type d \
                    -exec sh -c 'cd "$(dirname "{}")" && git gc --prune=now --quiet' \\; 2>/dev/null || true
                    """,
                safetyLevel: .safe,
                estimatedSavingsHint: "10–200 MB",
                requiresConfirmation: false
            ),
        ],
        description: "Version control. git gc compresses pack objects and removes unreachable objects."
    )

    static let androidStudio = DeveloperProfile(
        id: "android-studio",
        name: "Android Studio",
        icon: "app.badge.fill",
        color: .green,
        category: .editors,
        detectMethod: .bundleID("com.google.android.studio"),
        memoryProcessPatterns: ["studio", "java", "gradle"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "Gradle Cache",
                path: "~/.gradle/caches",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: "Gradle will re-download dependencies on next build."
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clean Gradle Cache",
                shellCommand: "rm -rf ~/.gradle/caches",
                safetyLevel: .moderate,
                estimatedSavingsHint: "500 MB – 10 GB",
                requiresConfirmation: true
            ),
        ],
        description: "Android IDE. Gradle caches and build outputs consume significant disk."
    )

    static let jetbrains = DeveloperProfile(
        id: "jetbrains",
        name: "JetBrains IDEs",
        icon: "diamond.fill",
        color: .pink,
        category: .editors,
        detectMethod: .directoryExists("~/Library/Application Support/JetBrains"),
        memoryProcessPatterns: ["idea", "pycharm", "webstorm", "goland", "clion", "rider"],
        diskScans: [
            DeveloperProfile.DiskScan(
                label: "JetBrains Caches",
                path: "~/Library/Caches/JetBrains",
                maxDepth: 1,
                safeToDelete: true,
                warningMessage: nil
            ),
        ],
        cleanupActions: [
            DeveloperProfile.CleanupAction(
                label: "Clear IDE Caches",
                shellCommand: "rm -rf ~/Library/Caches/JetBrains/*",
                safetyLevel: .moderate,
                estimatedSavingsHint: "200 MB – 3 GB",
                requiresConfirmation: true
            ),
        ],
        description: "JetBrains IDE suite. Index caches and build artifacts accumulate quickly."
    )
}