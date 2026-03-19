import SwiftUI

/// Auto-kill runaway processes management view
struct AutoKillView: View {
    @ObservedObject var autoKill = AutoKillManager.shared
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text("Runaway Process Guard")
                    .font(.title2.bold())
                Spacer()
                Toggle("", isOn: $settings.autoKillEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if settings.autoKillEnabled {
                // Thresholds
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memory Threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(String(format: "%.1f GB", settings.autoKillMemoryGB))
                                .font(.system(.body, design: .rounded, weight: .bold))
                            Slider(value: $settings.autoKillMemoryGB, in: 1...20, step: 0.5)
                                .frame(width: 120)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CPU Threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(String(format: "%.0f%%", settings.autoKillCPUPercent))
                                .font(.system(.body, design: .rounded, weight: .bold))
                            Slider(value: $settings.autoKillCPUPercent, in: 50...100, step: 5)
                                .frame(width: 120)
                        }
                    }

                    Toggle("Warn before kill", isOn: $settings.autoKillWarningFirst)
                        .toggleStyle(.checkbox)
                }

                Divider()

                // Currently monitored
                if !autoKill.monitoredProcesses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ Currently Elevated")
                            .font(.headline)
                            .foregroundColor(.orange)

                        ForEach(autoKill.monitoredProcesses) { proc in
                            HStack {
                                Text(proc.name)
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                Spacer()
                                Text(String(format: "%.1f GB", proc.memoryGB))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.red)
                                Text(proc.threat.rawValue)
                                    .font(.caption.bold())
                                    .foregroundColor(threatColor(proc.threat))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(threatColor(proc.threat).opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Button("Kill") {
                                    autoKill.killProcess(
                                        pid: proc.id,
                                        name: proc.name,
                                        reason: "Manual kill from monitor",
                                        memoryGB: proc.memoryGB
                                    )
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.green)
                        Text("All processes running normally")
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Kill log
                HStack {
                    Text("Kill History")
                        .font(.headline)
                    Spacer()
                    if !autoKill.killLog.isEmpty {
                        Button("Clear") { autoKill.clearLog() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                }

                if autoKill.killLog.isEmpty {
                    Text("No processes terminated yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(autoKill.killLog) { entry in
                                HStack(spacing: 8) {
                                    Image(systemName: entry.wasAutoKilled ? "bolt.fill" : "hand.raised.fill")
                                        .font(.caption)
                                        .foregroundColor(entry.wasAutoKilled ? .orange : .blue)

                                    Text(entry.processName)
                                        .font(.system(.caption, design: .rounded, weight: .medium))

                                    Text(String(format: "%.1f GB", entry.memoryGB))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)

                                    Text(entry.reason)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(entry.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }

                Divider()

                // Whitelist
                Text("Whitelisted Processes")
                    .font(.headline)

                FlowLayout(spacing: 6) {
                    ForEach(autoKill.whitelistedProcesses, id: \.self) { name in
                        HStack(spacing: 4) {
                            Text(name)
                                .font(.caption)
                            Button {
                                autoKill.removeFromWhitelist(name)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Auto-kill is disabled")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Enable to automatically terminate processes that exceed memory or CPU thresholds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
    }

    private func threatColor(_ level: AutoKillManager.RunawayCandidate.ThreatLevel) -> Color {
        switch level {
        case .warning: return .orange
        case .severe: return .red
        case .critical: return .purple
        }
    }
}

// Simple flow layout
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
}
