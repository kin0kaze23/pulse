//
//  HistoryChartsView.swift
//  Pulse
//
//  Chart visualization for historical system metrics
//

import SwiftUI
import Charts

struct HistoryChartsView: View {
    @StateObject private var historicalMetrics = HistoricalMetricsService.shared
    
    @State private var selectedTimeRange: TimeRange = .last6Hours
    @State private var selectedMetric: ChartMetric = .memory
    
    enum ChartMetric: String, CaseIterable, Identifiable {
        case memory = "Memory"
        case cpu = "CPU"
        case temperature = "Temperature"
        case disk = "Disk"
        
        var id: ChartMetric { self }
        
        var icon: String {
            switch self {
            case .memory: return "memorychip"
            case .cpu: return "cpu"
            case .temperature: return "thermometer"
            case .disk: return "internaldrive"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            
            if historicalMetrics.metrics.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .padding(20)
        .onAppear {
            historicalMetrics.startRecording()
        }
        .onDisappear {
            historicalMetrics.stopRecording()
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Historical Charts")
                    .font(.largeTitle.weight(.bold))
                
                Text("System metrics over time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Recording indicator
                if historicalMetrics.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button("Start Recording") {
                        historicalMetrics.startRecording()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Time range selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .fixedSize()
            }
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 20) {
            metricSelector
            
            chartView
                .frame(height: 300)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 1)
                )
            
            summaryCards
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xy.axis.line")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No historical data yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Start recording to collecting system metrics")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Start Recording") {
                historicalMetrics.startRecording()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 300)
    }
    
    private var metricSelector: some View {
        Picker("Metric", selection: $selectedMetric) {
            ForEach(ChartMetric.allCases, id: \.self) { metric in
                Label(metric.rawValue, systemImage: metric.icon)
                    .tag(metric)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedMetric) { _, _ in
            // Clear any selections or filters when switching metric
        }
    }
    
    private var chartView: some View {
        let filteredMetrics = historicalMetrics.getMetrics(for: selectedTimeRange)
        
        return Group {
            switch selectedMetric {
            case .memory:
                Chart(filteredMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Used RAM %", point.memoryUsedPercent)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)), anchor: .topTrailing)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(anchor: .trailing)
                    }
                }
                .frame(height: 250)
            case .cpu:
                Chart(filteredMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("CPU %", point.cpuUsagePercent)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)), anchor: .topTrailing)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(anchor: .trailing)
                    }
                }
                .frame(height: 250)
            case .temperature:
                let tempMetrics = filteredMetrics.filter { $0.temperatureCPU != nil || $0.temperatureGPU != nil }
                Chart(tempMetrics) { point in
                    if let cpuTemp = point.temperatureCPU {
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("CPU Temperature (°C)", cpuTemp)
                        )
                        .foregroundStyle(.red)
                    }
                    if let gpuTemp = point.temperatureGPU {
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("GPU Temperature (°C)", gpuTemp)
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)), anchor: .topTrailing)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(anchor: .trailing)
                    }
                }
                .frame(height: 250)
            case .disk:
                Chart(filteredMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Disk Used (GB)", point.diskUsedGB)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)), anchor: .topTrailing)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(anchor: .trailing)
                    }
                }
                .frame(height: 250)
            }
        }
    }
    
    private var summaryCards: some View {
        let filteredMetrics = historicalMetrics.getMetrics(for: selectedTimeRange)
        guard !filteredMetrics.isEmpty else { return AnyView(HStack {}.frame(height: 80)) }
        
        return AnyView(
            HStack(spacing: 16) {
                StatsCard(
                    title: "Avg Memory",
                    value: "\(String(format: "%.1f", historicalMetrics.getAverageMemoryUsage(for: selectedTimeRange).usedPercent))%",
                    unit: "",
                    icon: "memorychip",
                    color: .blue
                )
                
                StatsCard(
                    title: "Avg CPU",
                    value: "\(String(format: "%.1f", historicalMetrics.getAverageCPUUsage(for: selectedTimeRange)))%",
                    unit: "",
                    icon: "cpu",
                    color: .orange
                )
                
                StatsCard(
                    title: "Max Memory",
                    value: "\(String(formattedGB: filteredMetrics.map(\.memoryUsedGB).max() ?? 0))",
                    unit: "GB",
                    icon: "chart.bar.xaxis",
                    color: .purple
                )
                
                StatsCard(
                    title: "Recorded Period",
                    value: String(format: "%.0f", selectedTimeRange.seconds / (60 * 60)),
                    unit: "Hours",
                    icon: "clock",
                    color: .green
                )
            }
            .frame(height: 100)
        )
    }
    
    struct StatsCard: View {
        let title: String
        let value: String
        let unit: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    
                    Spacer()
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(value)
                        .font(.title2.bold())
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(minWidth: 140)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 1)
            )
        }
    }
}

extension String {
    init<C>(formattedGB value: C) where C: BinaryFloatingPoint {
        let doubleValue = Double(value)
        let formattedValue = "\(String(format: "%.1f", doubleValue))"
        if doubleValue >= 1024.0 {
            self = "\(String(format: "%.1f", doubleValue / 1024.0)) TB"
        } else {
            self = "\(formattedValue) GB"
        }
    }
}

#Preview {
    HistoryChartsView()
        .frame(width: 1000, height: 700)
}