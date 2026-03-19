import SwiftUI

/// Disk usage view with storage breakdown
struct DiskView: View {
    @ObservedObject var diskMonitor = DiskMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Storage")
                    .font(.title2.bold())
                Spacer()
                Button("Refresh") { diskMonitor.refresh() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            // Primary disk gauge
            if let disk = diskMonitor.primaryDisk {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 20) {
                        // Disk gauge
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 12)
                            Circle()
                                .trim(from: 0, to: min(disk.usedPercentage / 100.0, 1.0))
                                .stroke(
                                    disk.usedPercentage > 90 ? Color.red.gradient :
                                        disk.usedPercentage > 75 ? Color.orange.gradient :
                                        Color.orange.gradient,
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: disk.usedPercentage)

                            VStack(spacing: 2) {
                                Text(String(format: "%.0f%%", disk.usedPercentage))
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                Text("used")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 90, height: 90)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(disk.name)
                                .font(.headline)

                            DiskStatRow(label: "Used", value: String(format: "%.1f GB", disk.usedGB), color: .orange)
                            DiskStatRow(label: "Free", value: String(format: "%.1f GB", disk.freeGB), color: .green)
                            DiskStatRow(label: "Total", value: String(format: "%.0f GB", disk.totalGB), color: .primary)

                            Text(disk.fileSystem)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Spacer()
                    }

                    // Storage bar
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(
                                    disk.usedPercentage > 90 ? Color.red :
                                        disk.usedPercentage > 75 ? Color.orange :
                                        Color.orange.opacity(0.7)
                                )
                                .frame(width: geo.size.width * (disk.usedPercentage / 100.0))
                            Rectangle()
                                .fill(Color.green.opacity(0.3))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .frame(height: 14)

                    HStack {
                        Text("Used: \(String(format: "%.1f GB", disk.usedGB))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Free: \(String(format: "%.1f GB", disk.freeGB))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Other disks
            if diskMonitor.disks.count > 1 {
                Divider()
                Text("Other Volumes")
                    .font(.headline)

                ForEach(diskMonitor.disks.filter { $0.mountPath != "/" }) { disk in
                    HStack {
                        Image(systemName: disk.isRemovable ? "externaldrive" : "internaldrive")
                            .foregroundColor(.secondary)
                        Text(disk.name)
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.1f / %.0f GB", disk.usedGB, disk.totalGB))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)

                        ProgressView(value: disk.usedPercentage / 100.0)
                            .frame(width: 80)
                            .tint(disk.usedPercentage > 90 ? .red : disk.usedPercentage > 75 ? .orange : .blue)
                    }
                }
            }
        }
    }
}

struct DiskStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
    }
}

#Preview {
    DiskView()
        .padding()
}
