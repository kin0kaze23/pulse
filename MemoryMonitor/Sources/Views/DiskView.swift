import SwiftUI

/// Premium disk view with cleanup recommendations.
struct DiskView: View {
    @ObservedObject var diskMonitor = DiskMonitor.shared
    @ObservedObject var optimizer = MemoryOptimizer.shared
    @ObservedObject var comprehensive = ComprehensiveOptimizer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let disk = diskMonitor.primaryDisk {
                heroCard(disk)
            }

            cleanupCard

            if diskMonitor.disks.count > 1 {
                volumesCard
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Storage")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("See disk pressure, reclaim clutter, and keep swap healthy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                diskMonitor.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private func heroCard(_ disk: DiskMonitor.DiskInfo) -> some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: min(disk.usedPercentage / 100.0, 1.0))
                    .stroke(gaugeColor(for: disk).gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", disk.usedPercentage))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("used")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 12) {
                Text(disk.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                HStack(spacing: 12) {
                    premiumStat(label: "Used", value: String(format: "%.1f GB", disk.usedGB), tint: .orange)
                    premiumStat(label: "Free", value: String(format: "%.1f GB", disk.freeGB), tint: .green)
                    premiumStat(label: "Total", value: String(format: "%.0f GB", disk.totalGB), tint: .primary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(gaugeColor(for: disk).gradient)
                                .frame(width: geo.size.width * (disk.usedPercentage / 100.0))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.14))
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text(disk.fileSystem)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(disk.usedPercentage > 90 ? "Disk pressure is high" : "Healthy headroom")
                            .font(.caption2)
                            .foregroundColor(gaugeColor(for: disk))
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cleanupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reclaim Space")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Text("Safe cleanup targets that help disk pressure and swap performance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    optimizer.freeRAM()
                } label: {
                    if optimizer.isWorking {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Cleaning...")
                        }
                    } else {
                        Label("Clean Up", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(optimizer.isWorking)
            }

            if optimizer.isWorking {
                ProgressView(optimizer.statusMessage.isEmpty ? "Scanning..." : optimizer.statusMessage)
                    .controlSize(.small)
            } else if let plan = optimizer.pendingCleanupPlan, plan.items.isEmpty {
                Text("No meaningful cleanup targets right now.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let plan = optimizer.pendingCleanupPlan {
                ForEach(plan.items.prefix(5)) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(item.category.color))
                            .frame(width: 34, height: 34)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Text(item.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(item.sizeText)
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if plan.items.count > 5 {
                    Text("+ \(plan.items.count - 5) more items...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let result = optimizer.lastResult,
               Date().timeIntervalSince(result.timestamp) < 10,
               result.totalFreedMB > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var volumesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Volumes")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            ForEach(diskMonitor.disks.filter { $0.mountPath != "/" }) { disk in
                HStack(spacing: 12) {
                    Image(systemName: disk.isRemovable ? "externaldrive.fill" : "internaldrive.fill")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(disk.name)
                            .font(.subheadline)
                        Text(String(format: "%.1f / %.0f GB", disk.usedGB, disk.totalGB))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    ProgressView(value: disk.usedPercentage / 100.0)
                        .frame(width: 90)
                        .tint(gaugeColor(for: disk))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func premiumStat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(tint)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func gaugeColor(for disk: DiskMonitor.DiskInfo) -> Color {
        if disk.usedPercentage > 95 { return .red }
        if disk.usedPercentage > 85 { return .orange }
        return .blue
    }
}

#Preview {
    DiskView()
        .padding()
}