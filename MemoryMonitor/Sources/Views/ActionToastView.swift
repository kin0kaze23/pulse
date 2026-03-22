import SwiftUI

/// Animated toast notification for action feedback
struct ActionToastView: View {
    @ObservedObject var optimizer = MemoryOptimizer.shared
    @State private var dismissed = false

    var body: some View {
        VStack(spacing: 0) {
            if optimizer.isWorking {
                workingToast
            } else if let result = optimizer.lastResult,
                      !dismissed,
                      Date().timeIntervalSince(result.timestamp) < 10 {
                resultToast(result: result)
                    .onAppear {
                        // Auto-dismiss after 6 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                dismissed = true
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: optimizer.isWorking)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dismissed)
        .onChange(of: optimizer.isWorking) { _, working in
            if working {
                dismissed = false
            }
        }
    }

    // MARK: - Working State

    private var workingToast: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    ProgressView()
                        .controlSize(.small)
                        .tint(.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Optimizing...")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text(optimizer.statusMessage)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                        .id(optimizer.statusMessage)
                }

                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(optimizer.progress * 100))%")
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundColor(.accentColor)
                    Text(estimatedTimeRemaining)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar with gradient
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * optimizer.progress)
                        .animation(.easeInOut(duration: 0.3), value: optimizer.progress)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
    
    private var estimatedTimeRemaining: String {
        let remaining = 1.0 - optimizer.progress
        if remaining <= 0.05 { return "Done!" }
        if remaining <= 0.15 { return "~1 sec" }
        if remaining <= 0.30 { return "~2 sec" }
        if remaining <= 0.50 { return "~3 sec" }
        if remaining <= 0.70 { return "~5 sec" }
        return "~7 sec"
    }

    // MARK: - Result State

    private func resultToast(result: MemoryOptimizer.OptimizeResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(result.totalFreedMB > 0 ? Color.green.opacity(0.12) : Color.blue.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: result.totalFreedMB > 0 ? "checkmark.circle.fill" : "info.circle.fill")
                        .font(.body)
                        .foregroundColor(result.totalFreedMB > 0 ? .green : .blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Optimization Complete")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text(result.summary)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        dismissed = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            
            // Show detailed steps
            if !result.steps.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.steps.prefix(5), id: \.name) { step in
                        HStack(spacing: 6) {
                            Image(systemName: step.success ? "checkmark" : "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(step.success ? .green : .red)
                            
                            Text(step.name)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if step.freedMB > 0 {
                                Text("\(Int(step.freedMB)) MB")
                                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if result.steps.count > 5 {
                        Text("+ \(result.steps.count - 5) more items")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
}
