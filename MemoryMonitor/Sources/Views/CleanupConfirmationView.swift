import SwiftUI

/// Premium cleanup confirmation dialog - shows what will be cleaned before destructive operations
struct CleanupConfirmationView: View {
    @ObservedObject var optimizer = MemoryOptimizer.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismiss on tap
            
            // Dialog card
            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    if let plan = optimizer.pendingCleanupPlan {
                        cleanupItemsList(plan)
                    }
                }
                .frame(maxHeight: 300)
                Divider()
                footer
            }
            .frame(width: 480)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cleanup Required")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Review what will be cleaned before proceeding")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(16)

            // Summary pill
            if let plan = optimizer.pendingCleanupPlan {
                HStack(spacing: 12) {
                    SummaryPill(icon: "doc.on.doc", value: "\(plan.itemCount) items", color: .blue)
                    SummaryPill(icon: "arrow.down.circle", value: plan.totalSizeText, color: .green)
                }
            }

            // Permanent deletion warning
            if let plan = optimizer.pendingCleanupPlan, plan.items.contains(where: { $0.isDestructive }) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This action is permanent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                        Text("Some files will be permanently deleted and cannot be recovered. User data goes to Trash.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Cleanup Items List
    
    private func cleanupItemsList(_ plan: ComprehensiveOptimizer.CleanupPlan) -> some View {
        VStack(spacing: 16) {
            // Group by category
            ForEach(categoryGroups(from: plan.items), id: \.category) { group in
                CategorySection(category: group.category, items: group.items)
            }
        }
        .padding(16)
    }
    
    private func categoryGroups(from items: [ComprehensiveOptimizer.CleanupPlan.CleanupItem]) -> [(category: OptimizeResult.Category, items: [ComprehensiveOptimizer.CleanupPlan.CleanupItem])] {
        let grouped = Dictionary(grouping: items) { $0.category }
        return OptimizeResult.Category.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 12) {
            // Cancel
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    optimizer.cancelCleanup()
                }
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 100)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
            
            Spacer()
            
            // Destructive warning indicator
            if let plan = optimizer.pendingCleanupPlan, plan.items.contains(where: { $0.isDestructive }) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text("Contains destructive operations")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Confirm
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    optimizer.executeCleanup()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11))
                    Text("Clean Up")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .frame(minWidth: 120)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.gradient)
            )
            .foregroundColor(.white)
        }
        .padding(16)
    }
}

// MARK: - Supporting Views

struct SummaryPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

struct CategorySection: View {
    let category: OptimizeResult.Category
    let items: [ComprehensiveOptimizer.CleanupPlan.CleanupItem]
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Button {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(categoryColor)
                        .frame(width: 20)
                    
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    
                    Text("(\(items.count))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(categoryTotal)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(categoryColor)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Items
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(items.prefix(5)) { item in
                        CleanupItemRow(item: item)
                    }
                    if items.count > 5 {
                        Text("+ \(items.count - 5) more items")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var categoryColor: Color {
        switch category {
        case .developer: return .purple
        case .browser: return .blue
        case .application: return .cyan
        case .system: return .green
        case .memory: return .orange
        case .disk: return .red
        case .logs: return .yellow
        }
    }
    
    private var categoryTotal: String {
        let total = items.reduce(0) { $0 + $1.sizeMB }
        if total > 1024 {
            return String(format: "%.1f GB", total / 1024)
        }
        return String(format: "%.0f MB", total)
    }
}

struct CleanupItemRow: View {
    let item: ComprehensiveOptimizer.CleanupPlan.CleanupItem
    
    var body: some View {
        HStack {
            Image(systemName: item.isDestructive ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.system(size: 10))
                .foregroundColor(item.isDestructive ? .orange : .green)
                .frame(width: 16)
            
            Text(item.name)
                .font(.system(size: 11))
                .lineLimit(1)
            
            Spacer()
            
            Text(item.sizeText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

#Preview {
    CleanupConfirmationView()
}
