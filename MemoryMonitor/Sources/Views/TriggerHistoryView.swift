import SwiftUI

/// Trigger history timeline view
struct TriggerHistoryView: View {
    @ObservedObject private var metricsService = HistoricalMetricsService.shared

    @State private var selectedFilter: TriggerFilter = .all
    @State private var events: [TriggerEvent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerSection

            // Statistics summary cards
            statisticsSection

            // Filter picker
            filterSection

            // Events timeline
            eventsListSection
        }
        .padding()
        .onAppear {
            loadEvents()
        }
        .onChange(of: selectedFilter) { _, _ in
            loadEvents()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Trigger History")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: { loadEvents() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }

    private var statisticsSection: some View {
        let stats = metricsService.getTriggerStatistics()

        return HStack(spacing: 12) {
            TriggerStatCard(
                title: "Today",
                value: "\(stats.todayEvents)",
                icon: "calendar",
                color: .blue
            )

            TriggerStatCard(
                title: "This Week",
                value: "\(stats.weekEvents)",
                icon: "calendar.badge.clock",
                color: .purple
            )

            TriggerStatCard(
                title: "Freed",
                value: String(format: "%.0f MB", stats.totalFreedMB),
                icon: "arrow.down.circle",
                color: .green
            )

            TriggerStatCard(
                title: "Success",
                value: String(format: "%.0f%%", stats.successRate),
                icon: "checkmark.circle",
                color: stats.successRate > 80 ? .green : .orange
            )
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TriggerFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
        }
    }

    private var eventsListSection: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView(
                    "No trigger events",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Trigger events will appear here once automation actions run")
                )
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(events) { event in
                            TriggerEventRow(event: event)
                        }
                    }
                }
                .frame(minHeight: 200)
            }
        }
    }

    // MARK: - Actions

    private func loadEvents() {
        events = metricsService.getTriggerEvents(filter: selectedFilter)
    }
}

// MARK: - Supporting Views

struct TriggerStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TriggerEventRow: View {
    let event: TriggerEvent

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: event.type.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if !event.success {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Text(event.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    if let val = event.value {
                        Label(String(format: "%.0f%%", val), systemImage: "gauge.with.needle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let freed = event.freedMB, freed > 0 {
                        Label(String(format: "%.1f MB freed", freed), systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    if let processName = event.processName {
                        Label(processName, systemImage: "app.badge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = event.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconColor: Color {
        if !event.success {
            return .red
        }

        switch event.type.category {
        case .system:
            return .blue
        case .automation:
            return .purple
        case .scheduled:
            return .green
        case .manual:
            return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    TriggerHistoryView()
        .frame(width: 400, height: 600)
}