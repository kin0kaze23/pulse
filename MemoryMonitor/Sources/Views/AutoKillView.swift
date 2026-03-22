import SwiftUI

/// Auto-kill runaway processes management view - Premium implementation
struct AutoKillView: View {
    @ObservedObject var autoKill = AutoKillManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header
            
            if settings.autoKillEnabled {
                enabledContent
            } else {
                disabledContent
            }
        }
        .premiumCard()
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "shield.checkered")
                .font(.title2)
                .foregroundStyle(.red)
            Text("Runaway Process Guard")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            Toggle("", isOn: $settings.autoKillEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
    
    // MARK: - Enabled Content
    
    private var enabledContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            thresholdsSection
            
            Divider()
            
            monitoredProcessesSection
            
            Divider()
            
            killHistorySection
            
            Divider()
            
            whitelistSection
        }
    }
    
    // MARK: - Thresholds
    
    private var thresholdsSection: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            thresholdControl(
                label: "Memory Threshold",
                value: String(format: "%.1f GB", settings.autoKillMemoryGB),
                slider: Slider(value: $settings.autoKillMemoryGB, in: 1...20, step: 0.5)
            )
            
            thresholdControl(
                label: "CPU Threshold",
                value: String(format: "%.0f%%", settings.autoKillCPUPercent),
                slider: Slider(value: $settings.autoKillCPUPercent, in: 50...100, step: 5)
            )
            
            Toggle("Warn before kill", isOn: $settings.autoKillWarningFirst)
                .toggleStyle(.checkbox)
            
            Spacer()
        }
    }
    
    private func thresholdControl(label: String, value: String, slider: some View) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(value)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.bold)
                slider
                    .frame(width: 100)
            }
        }
    }
    
    // MARK: - Monitored Processes
    
    private var monitoredProcessesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if !autoKill.monitoredProcesses.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Currently Elevated")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.orange)
                }
                
                ForEach(autoKill.monitoredProcesses) { proc in
                    processRow(proc)
                }
            } else {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("All processes running normally")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func processRow(_ proc: AutoKillManager.RunawayCandidate) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(proc.name)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(String(format: "%.1f GB", proc.memoryGB))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.red)
            
            Text(proc.threat.rawValue)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(threatColor(proc.threat))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(threatColor(proc.threat).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Button {
                autoKill.killProcess(
                    pid: proc.id,
                    name: proc.name,
                    reason: "Manual kill from monitor",
                    memoryGB: proc.memoryGB
                )
            } label: {
                Text("Kill")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
    }
    
    // MARK: - Kill History
    
    private var killHistorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Kill History")
                    .font(DesignSystem.Typography.headline)
                Spacer()
                if !autoKill.killLog.isEmpty {
                    Button("Clear") { autoKill.clearLog() }
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            if autoKill.killLog.isEmpty {
                Text("No processes terminated yet")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        ForEach(autoKill.killLog) { entry in
                            killLogRow(entry)
                        }
                    }
                }
                .frame(maxHeight: 100)
            }
        }
    }
    
    private func killLogRow(_ entry: AutoKillManager.KillLogEntry) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: entry.wasAutoKilled ? "bolt.fill" : "hand.raised.fill")
                .font(.caption)
                .foregroundColor(entry.wasAutoKilled ? .orange : .blue)
            
            Text(entry.processName)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
            
            Text(String(format: "%.1f GB", entry.memoryGB))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            
            Text(entry.reason)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            Text(entry.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Whitelist
    
    private var whitelistSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Whitelisted Processes")
                .font(DesignSystem.Typography.headline)
            
            if autoKill.whitelistedProcesses.isEmpty {
                Text("No whitelisted processes")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(autoKill.whitelistedProcesses, id: \.self) { name in
                        whitelistChip(name)
                    }
                }
            }
        }
    }
    
    private func whitelistChip(_ name: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "app.fill")
                .font(.caption2)
                .foregroundColor(.blue)
            Text(name)
                .font(.system(.caption, design: .rounded))
            Button {
                autoKill.removeFromWhitelist(name)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Disabled Content
    
    private var disabledContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "shield.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Auto-kill is disabled")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(.secondary)
            Text("Enable to automatically terminate processes that exceed memory or CPU thresholds")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }
    
    // MARK: - Helpers
    
    private func threatColor(_ level: AutoKillManager.RunawayCandidate.ThreatLevel) -> Color {
        switch level {
        case .warning: return .orange
        case .severe: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }
        
        return (CGSize(width: totalWidth, height: y + maxHeight), positions)
    }
}

#Preview {
    AutoKillView()
        .padding()
        .frame(width: 500)
}
