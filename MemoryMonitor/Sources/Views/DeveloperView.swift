import SwiftUI

/// Developer profiles view — shows detected dev tools, their disk usage, and cleanup actions
struct DeveloperView: View {
    @ObservedObject var engine = DeveloperProfilesEngine.shared
    @State private var confirmAction: DeveloperProfile.CleanupAction?
    @State private var confirmProfile: DeveloperProfile?
    @State private var isExecuting = false
    @State private var lastResult: String?
    @State private var showAddCustomRule = false
    @State private var newRuleName = ""
    @State private var newRuleCommand = ""
    @State private var newRuleDescription = ""

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader

            if engine.isRefreshing && engine.profileStates.isEmpty {
                loadingState
            } else if engine.profileStates.isEmpty {
                emptyState
            } else {
                profilesList
            }

            customRulesSection
        }
        .padding(DesignSystem.Spacing.lg)
        .onAppear { engine.refresh() }
        .alert("Confirm Action", isPresented: .init(
            get: { confirmAction != nil },
            set: { if !$0 { confirmAction = nil; confirmProfile = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                confirmAction = nil
                confirmProfile = nil
            }
            Button("Execute", role: .destructive) {
                if let action = confirmAction {
                    Task { await executeAction(action) }
                }
            }
        } message: {
            if let action = confirmAction {
                Text("\(action.label)\n\n\(action.estimatedSavingsHint ?? "")")
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Developer Tools")
                        .font(.title2.bold())
                    Text("\(engine.profileStates.count) tools detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                engine.refresh()
            } label: {
                Image(systemName: engine.isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                    .rotationEffect(.degrees(engine.isRefreshing ? 360 : 0))
                    .animation(engine.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: engine.isRefreshing)
            }
            .buttonStyle(.plain)
            .disabled(engine.isRefreshing)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Scanning for developer tools...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Developer Tools Detected")
                .font(.headline)
            Text("Install Xcode, Docker, Node.js, or other development tools to see them here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Profiles List

    private var profilesList: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(engine.profileStates) { state in
                ProfileCard(state: state) { action in
                    if action.requiresConfirmation {
                        confirmAction = action
                        confirmProfile = state.profile
                    } else {
                        Task { await executeAction(action) }
                    }
                }
            }
        }
    }

    // MARK: - Custom Rules Section

    private var customRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Rules")
                    .font(.headline)
                Spacer()
                Button {
                    showAddCustomRule.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            if engine.customRules.isEmpty {
                Text("No custom rules. Add your own cleanup commands.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(engine.customRules) { rule in
                    HStack {
                        Image(systemName: rule.icon)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text(rule.name)
                                .font(.subheadline.bold())
                            Text(rule.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await executeCustomRule(rule) }
                        } label: {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.plain)
                        Button {
                            engine.removeCustomRule(id: rule.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if showAddCustomRule {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $newRuleName)
                    TextField("Shell command", text: $newRuleCommand)
                        .font(.system(.body, design: .monospaced))
                    TextField("Description", text: $newRuleDescription)
                    HStack {
                        Button("Cancel") {
                            showAddCustomRule = false
                            newRuleName = ""
                            newRuleCommand = ""
                            newRuleDescription = ""
                        }
                        Spacer()
                        Button("Add") {
                            let rule = DeveloperProfilesEngine.CustomRule(
                                name: newRuleName,
                                icon: "terminal",
                                cleanupCommand: newRuleCommand,
                                description: newRuleDescription
                            )
                            engine.addCustomRule(rule)
                            showAddCustomRule = false
                            newRuleName = ""
                            newRuleCommand = ""
                            newRuleDescription = ""
                        }
                        .disabled(newRuleName.isEmpty || newRuleCommand.isEmpty)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func executeAction(_ action: DeveloperProfile.CleanupAction) async {
        await MainActor.run { isExecuting = true }
        let result = await engine.executeAction(action)
        await MainActor.run {
            isExecuting = false
            lastResult = result.success ? "✓ \(action.label)" : "✗ \(result.output)"
            // Refresh after cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                engine.refresh()
            }
        }
    }

    private func executeCustomRule(_ rule: DeveloperProfilesEngine.CustomRule) async {
        let action = DeveloperProfile.CleanupAction(
            label: rule.name,
            shellCommand: rule.cleanupCommand,
            safetyLevel: .moderate,
            estimatedSavingsHint: nil,
            requiresConfirmation: true
        )
        await executeAction(action)
    }
}

// MARK: - Profile Card

struct ProfileCard: View {
    let state: DeveloperProfilesEngine.ProfileState
    let onAction: (DeveloperProfile.CleanupAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: state.profile.icon)
                    .font(.title3)
                    .foregroundColor(state.profile.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.profile.name)
                        .font(.headline)
                    Text(state.profile.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if state.isRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }

            // Memory usage if running
            if state.isRunning && state.memoryMB > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(formatMemory(state.memoryMB))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Disk scans
            if !state.diskSizes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(state.diskSizes.keys.sorted()), id: \.self) { label in
                        if let size = state.diskSizes[label], size > 0 {
                            HStack {
                                Text(label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatDisk(size))
                                    .font(.caption.bold())
                                    .foregroundColor(size > 1024 ? .orange : .primary)
                            }
                        }
                    }
                }
            }

            // Cleanup actions
            if !state.profile.cleanupActions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(state.profile.cleanupActions.prefix(3)) { action in
                        Button {
                            onAction(action)
                        } label: {
                            HStack {
                                Image(systemName: safetyIcon(action.safetyLevel))
                                    .foregroundColor(safetyColor(action.safetyLevel))
                                    .font(.caption)
                                Text(action.label)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                                if let hint = action.estimatedSavingsHint {
                                    Text(hint)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(safetyColor(action.safetyLevel).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Description
            Text(state.profile.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb > 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func formatDisk(_ mb: Double) -> String {
        if mb > 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func safetyIcon(_ level: DeveloperProfile.CleanupAction.SafetyLevel) -> String {
        switch level {
        case .safe: return "checkmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .destructive: return "xmark.octagon"
        }
    }

    private func safetyColor(_ level: DeveloperProfile.CleanupAction.SafetyLevel) -> Color {
        switch level {
        case .safe: return .green
        case .moderate: return .orange
        case .destructive: return .red
        }
    }
}