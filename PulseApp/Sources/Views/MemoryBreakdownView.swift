import SwiftUI

/// Memory breakdown bar showing different memory categories
struct MemoryBreakdownView: View {
    let memory: SystemMemoryInfo

    struct MemorySegment: Identifiable {
        let id = UUID()
        let label: String
        let bytes: UInt64
        let color: Color

        var gb: Double { Double(bytes) / (1024 * 1024 * 1024) }
        var percentage: Double { 0 } // calculated later
    }

    var segments: [MemorySegment] {
        let total = Double(memory.totalBytes)
        guard total > 0 else { return [] }

        let segs: [MemorySegment] = [
            MemorySegment(label: "App Memory", bytes: memory.appMemoryBytes, color: .blue),
            MemorySegment(label: "Wired", bytes: memory.wiredBytes, color: .purple),
            MemorySegment(label: "Compressed", bytes: memory.compressedBytes, color: .cyan),
            MemorySegment(label: "Cached", bytes: memory.cachedBytes, color: .gray),
            MemorySegment(label: "Free", bytes: memory.freeBytes, color: Color(.systemGreen).opacity(0.3))
        ]

        return segs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Breakdown")
                .font(.headline)

            // Stacked bar
            GeometryReader { geo in
                let total = Double(memory.totalBytes)
                HStack(spacing: 0) {
                    ForEach(segments) { seg in
                        let width = total > 0 ? geo.size.width * (Double(seg.bytes) / total) : 0
                        if width > 0 {
                            Rectangle()
                                .fill(seg.color)
                                .frame(width: max(width, 2))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 24)

            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(segments) { seg in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(seg.color)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(seg.label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f GB", seg.gb))
                                .font(.caption.bold())
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MemoryBreakdownView(memory: SystemMemoryInfo(
        timestamp: Date(),
        totalBytes: 16 * 1024 * 1024 * 1024,
        usedBytes: 10 * 1024 * 1024 * 1024,
        freeBytes: 2 * 1024 * 1024 * 1024,
        cachedBytes: 3 * 1024 * 1024 * 1024,
        compressedBytes: 1 * 1024 * 1024 * 1024,
        wiredBytes: 2 * 1024 * 1024 * 1024,
        activeBytes: 5 * 1024 * 1024 * 1024,
        inactiveBytes: 2 * 1024 * 1024 * 1024,
        swapUsedBytes: 500 * 1024 * 1024,
        swapTotalBytes: 2 * 1024 * 1024 * 1024,
        appMemoryBytes: 5 * 1024 * 1024 * 1024
    ))
    .padding()
}
