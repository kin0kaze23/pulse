//
//  TemperatureGaugeView.swift
//  Pulse
//
//  Premium temperature gauge with animated ring and thermal zones
//  Inspired by Apple Watch complications and premium dashboard designs
//

import SwiftUI

// MARK: - Temperature Gauge

/// Premium circular temperature gauge with thermal zones
struct TemperatureGaugeView: View {
    let temperature: Double
    let label: String
    let icon: String
    let size: CGFloat
    
    @State private var animatedValue: Double = 0
    @State private var isGlowing: Bool = false
    
    init(temperature: Double, label: String = "CPU", icon: String = "cpu", size: CGFloat = 100) {
        self.temperature = temperature
        self.label = label
        self.icon = icon
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.primary.opacity(0.1),
                    lineWidth: ringWidth
                )
            
            // Temperature arc
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(
                    temperatureGradient,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: glowColor.opacity(isGlowing ? 0.6 : 0.3), radius: isGlowing ? 8 : 4)
                .animation(.easeInOut(duration: 0.3), value: animatedProgress)
            
            // Center content
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: size * 0.18, weight: .medium))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)
                
                Text(temperatureText)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                
                Text(label)
                    .font(.system(size: size * 0.12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedValue = temperature
            }
            startGlowAnimation()
        }
        .onChange(of: temperature) { newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedValue = newValue
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var ringWidth: CGFloat { size * 0.1 }
    
    private var animatedProgress: Double {
        // Map temperature 0-100°C to 0-1 progress
        min(animatedValue / 100.0, 1.0)
    }
    
    private var temperatureText: String {
        if animatedValue > 0 {
            return String(format: "%.0f°", animatedValue)
        }
        return "--°"
    }
    
    private var iconColor: Color {
        Color.temperature(temperature)
    }
    
    private var glowColor: Color {
        Color.temperature(temperature)
    }
    
    private var temperatureGradient: AngularGradient {
        AngularGradient(
            colors: gradientColors,
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * animatedProgress)
        )
    }
    
    private var gradientColors: [Color] {
        // Dynamic gradient based on temperature
        if temperature < 40 {
            return [.green.opacity(0.8), .green]
        } else if temperature < 60 {
            return [.green, .yellow]
        } else if temperature < 75 {
            return [.yellow, .orange]
        } else {
            return [.orange, .red]
        }
    }
    
    // MARK: - Animations
    
    private func startGlowAnimation() {
        // Subtle pulse effect for higher temperatures
        if temperature > 70 {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

// MARK: - Compact Temperature Card

/// Compact temperature card for dashboards
struct TemperatureCardView: View {
    let temperature: Double
    let label: String
    let icon: String
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(thermalColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(thermalColor)
            }
            
            // Temperature info
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(temperature > 0 ? String(format: "%.0f", temperature) : "--")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    
                    Text("°C")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Thermal indicator
            thermalIndicator
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.05 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(thermalColor.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var thermalColor: Color {
        Color.temperature(temperature)
    }
    
    @ViewBuilder
    private var thermalIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(thermalColor)
                .frame(width: 6, height: 6)
            
            Text(thermalStateText)
                .font(.caption2)
                .foregroundColor(thermalColor)
        }
    }
    
    private var thermalStateText: String {
        switch temperature {
        case 0..<50: return "Cool"
        case 50..<70: return "Warm"
        case 70..<85: return "Hot"
        default: return "Critical"
        }
    }
}

// MARK: - Temperature Ring (Small)

/// Small temperature ring for compact displays
struct TemperatureRingView: View {
    let temperature: Double
    
    @State private var animatedValue: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: min(animatedValue / 100.0, 1.0))
                .stroke(
                    Color.temperature(temperature),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 1) {
                Text(temperature > 0 ? String(format: "%.0f°", temperature) : "--°")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
        }
        .frame(width: 40, height: 40)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animatedValue = temperature
            }
        }
        .onChange(of: temperature) { newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Temperature History Sparkline

/// Mini sparkline chart for temperature history
struct TemperatureSparklineView: View {
    let temperatures: [Double]
    let range: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = temperatures.enumerated().map { index, temp in
                    CGPoint(
                        x: CGFloat(index) / CGFloat(max(temperatures.count - 1, 1)) * geometry.size.width,
                        y: geometry.size.height - ((temp - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height
                    )
                }
                
                if let firstPoint = points.first {
                    path.move(to: firstPoint)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
            
            // Fill gradient
            Path { path in
                let points = temperatures.enumerated().map { index, temp in
                    CGPoint(
                        x: CGFloat(index) / CGFloat(max(temperatures.count - 1, 1)) * geometry.size.width,
                        y: geometry.size.height - ((temp - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.height
                    )
                }
                
                if let firstPoint = points.first {
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: firstPoint)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
            }
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Thermal Status Banner

/// Animated thermal status banner
struct ThermalStatusBannerView: View {
    let maxTemperature: Double
    
    @State private var pulseAnimation: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(thermalColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulseAnimation && isCritical ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Image(systemName: thermalIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(thermalColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(thermalTitle)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(thermalMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Temperature value
            Text(String(format: "%.0f°C", maxTemperature))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(thermalColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(thermalColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(thermalColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            pulseAnimation = true
        }
    }
    
    private var thermalColor: Color {
        Color.temperature(maxTemperature)
    }
    
    private var thermalIcon: String {
        switch maxTemperature {
        case 0..<50: return "thermometer.medium.snowflake"
        case 50..<70: return "thermometer.medium"
        case 70..<85: return "thermometer.sun"
        default: return "thermometer.sun.fill"
        }
    }
    
    private var thermalTitle: String {
        switch maxTemperature {
        case 0..<50: return "System Cool"
        case 50..<70: return "System Warm"
        case 70..<85: return "System Hot"
        default: return "Thermal Warning"
        }
    }
    
    private var thermalMessage: String {
        switch maxTemperature {
        case 0..<50: return "Temperatures are optimal"
        case 50..<70: return "Normal operating temperature"
        case 70..<85: return "Consider closing heavy apps"
        default: return "Close resource-intensive applications"
        }
    }
    
    private var isCritical: Bool {
        maxTemperature >= 85
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            TemperatureGaugeView(temperature: 45, label: "CPU", icon: "cpu")
            TemperatureGaugeView(temperature: 68, label: "GPU", icon: "gpu")
            TemperatureGaugeView(temperature: 88, label: "Memory", icon: "memorychip")
        }
        
        TemperatureCardView(temperature: 52, label: "CPU", icon: "cpu")
        
        ThermalStatusBannerView(maxTemperature: 72)
        
        HStack(spacing: 12) {
            TemperatureRingView(temperature: 45)
            TemperatureRingView(temperature: 68)
            TemperatureRingView(temperature: 85)
        }
    }
    .padding()
    .frame(width: 400)
}