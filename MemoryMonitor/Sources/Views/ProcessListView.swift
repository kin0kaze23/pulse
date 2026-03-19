import SwiftUI

/// List of top memory-consuming processes
struct ProcessListView: View {
    @ObservedObject var processMonitor = ProcessMemoryMonitor.shared
    @ObservedObject var manager = MemoryMonitorManager.shared
    @State private var selectedProcess: ProcessMemoryInfo?
    @State private var showKillConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Memory Consumers")
                    .font(.headline)
                Spacer()
                Button {
                    processMonitor.refresh(topN: AppSettings.shared.topProcessesCount)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if processMonitor.topProcesses.isEmpty {
                ContentUnavailableView("No data", systemImage: "cpu")
                    .frame(height: 200)
            } else {
                Table(processMonitor.topProcesses) {
                    TableColumn("") { process in
                        ProcessIconView(pid: process.id, name: process.name)
                    }
                    .width(32)

                    TableColumn("Process") { process in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(process.name)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.medium)
                            if let path = process.path {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    TableColumn("Memory") { process in
                        Text(String(format: "%.1f MB", process.memoryMB))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                    .width(100)

                    TableColumn("Usage") { process in
                        HStack(spacing: 8) {
                            MemoryBar(percentage: process.memoryPercentage)
                            Text(String(format: "%.1f%%", process.memoryPercentage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                    .width(150)

                    TableColumn("") { process in
                        Button {
                            selectedProcess = process
                            showKillConfirmation = true
                        } label: {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.borderless)
                        .help("Terminate \(process.name)")
                    }
                    .width(32)
                }
                .frame(minHeight: 200, maxHeight: 400)
            }
        }
        .alert("Terminate Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Terminate", role: .destructive) {
                if let process = selectedProcess {
                    manager.processMonitor.killProcess(pid: process.id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        processMonitor.refresh(topN: AppSettings.shared.topProcessesCount)
                    }
                }
            }
        } message: {
            if let process = selectedProcess {
                Text("Are you sure you want to terminate \"\(process.name)\" (PID: \(process.id))? Unsaved data may be lost.")
            }
        }
    }
}

// MARK: - Memory Bar

struct MemoryBar: View {
    let percentage: Double

    private var barColor: Color {
        if percentage > 20 { return .red }
        if percentage > 10 { return .orange }
        if percentage > 5 { return .yellow }
        return .blue
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor.gradient)
                    .frame(width: geo.size.width * min(percentage / 30.0, 1.0))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Process Icon

struct ProcessIconView: View {
    let pid: Int32
    let name: String

    var body: some View {
        if let icon = ProcessMemoryMonitor.shared.iconForProcess(pid: pid) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    ProcessListView()
        .padding()
}
