import SwiftUI

/// Smart suggestions view - provides actionable advice for memory optimization
struct SmartSuggestionsView: View {
    @StateObject private var suggestions = SmartSuggestions.shared
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header

            if suggestions.suggestions.isEmpty {
                emptyState
            } else {
                suggestionsList
            }
        }
        .premiumCard()
        .onAppear {
            suggestions.analyze()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Smart Suggestions")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Actions to improve your Mac's performance")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                suggestions.analyze()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Refresh suggestions")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Looking good!")
                    .font(DesignSystem.Typography.headline)
                Text("No specific suggestions right now. Your Mac is running well.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(suggestions.suggestions) { suggestion in
                SuggestionRow(suggestion: suggestion)
            }
        }
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let suggestion: SmartSuggestions.Suggestion
    @State private var isPressed = false

    var body: some View {
        Button {
            handleAction(suggestion.action)
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)

                // Icon
                Image(systemName: suggestion.icon)
                    .font(.title3)
                    .foregroundColor(priorityColor)
                    .frame(width: 32)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(suggestion.detail)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Potential savings
                VStack(alignment: .trailing, spacing: 2) {
                    Text(suggestion.potentialSavings)
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundColor(.green)

                    Image(systemName: actionIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(priorityColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
            }
        }
    }

    private var priorityColor: Color {
        switch suggestion.priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }

    private var actionIcon: String {
        switch suggestion.action {
        case .restartApp, .restartMac, .stopDocker, .closeXcode:
            return "arrow.clockwise"
        case .closeBrowserTabs, .reduceSafariTabs:
            return "xmark.circle"
        case .reduceStartupItems:
            return "gear"
        case .clearDownloads:
            return "trash"
        case .cleanTimeMachine:
            return "clock.arrow.circlepath"
        case .cleanIOSUpdates:
            return "iphone"
        case .cleanNodeModules:
            return "cube.box"
        case .cleanIOSBackups:
            return "externaldrive"
        case .cleanLargeFiles:
            return "doc.fill"
        case .cleanMessages:
            return "message.fill"
        case .deepScan:
            return "sparkles"
        case .noAction:
            return "info.circle"
        }
    }

    private func handleAction(_ action: SmartSuggestions.Suggestion.Action) {
        switch action {
        case .restartApp(let name):
            restartApp(named: name)
        case .restartMac:
            restartMac()
        case .stopDocker:
            stopDocker()
        case .closeBrowserTabs, .reduceSafariTabs:
            openSafari()
        case .clearDownloads:
            openDownloads()
        case .reduceStartupItems:
            openSystemPreferences()
        case .closeXcode:
            closeXcode()
        case .cleanTimeMachine:
            showTimeMachineCleanup()
        case .cleanIOSUpdates, .cleanNodeModules, .cleanIOSBackups, .cleanLargeFiles, .cleanMessages, .deepScan:
            openStorageView()
        case .noAction:
            break
        }
    }

    private func restartApp(named name: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName == name }),
           let bundleURL = app.bundleURL {
            let appPath = bundleURL.deletingLastPathComponent().deletingLastPathComponent().path
            app.terminate()
            // Offer to restart after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSWorkspace.shared.open(URL(fileURLWithPath: appPath))
            }
        }
    }

    private func restartMac() {
        let alert = NSAlert()
        alert.messageText = "Restart Your Mac?"
        alert.informativeText = "This will restart your Mac to clear memory. Make sure to save your work first."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "tell app \"System Events\" to restart"]
            try? task.run()
        }
    }

    private func stopDocker() {
        // Stop all running Docker containers using shell for variable expansion
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "docker stop $(docker ps -q) 2>/dev/null || true"]
        try? task.run()
    }

    private func openSafari() {
        NSWorkspace.shared.launchApplication("Safari")
    }

    private func openDownloads() {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        NSWorkspace.shared.open(downloads)
    }

    private func openSystemPreferences() {
        // Open Login Items settings - works on modern macOS
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback for older macOS
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Accounts.prefPane"))
        }
    }

    private func closeXcode() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-x", "Xcode"]
        try? task.run()
    }
    
    private func showTimeMachineCleanup() {
        // Show confirmation dialog for Time Machine cleanup
        let alert = NSAlert()
        alert.messageText = "Delete Time Machine Snapshots?"
        alert.informativeText = "Local Time Machine snapshots can be safely deleted. Your iCloud and external backups remain intact. This can free significant disk space."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Delete All")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            TimeMachineManager.shared.deleteAllSnapshots { freedGB in
                print("[SmartSuggestions] Deleted Time Machine snapshots, freed \(freedGB)GB")
            }
        }
    }
    
    private func openStorageView() {
        // Navigate to storage cleanup or run optimizer
        MemoryOptimizer.shared.freeRAM()
    }
}

// MARK: - Preview

#Preview {
    SmartSuggestionsView()
        .padding()
        .frame(width: 500)
}
