import SwiftUI

/// Circular memory gauge showing usage percentage
struct MemoryGaugeView: View {
    let percentage: Double
    let pressureLevel: MemoryPressureLevel
    var size: CGFloat = 160

    private var gaugeColor: Color {
        switch pressureLevel {
        case .normal:    return DesignSystem.ColorPalette.Health.excellent
        case .warning:   return DesignSystem.ColorPalette.Health.poor
        case .critical:  return DesignSystem.ColorPalette.Health.critical
        }
    }

    private var gradientColors: [Color] {
        switch pressureLevel {
        case .normal:    return [DesignSystem.ColorPalette.Health.excellent, DesignSystem.ColorPalette.Health.excellent.opacity(0.6)]
        case .warning:   return [DesignSystem.ColorPalette.Health.poor, DesignSystem.ColorPalette.Health.fair]
        case .critical:  return [DesignSystem.ColorPalette.Health.critical, DesignSystem.ColorPalette.Health.poor]
        }
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(percentage / 100.0, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270 - 360 * percentage / 100.0)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: percentage)

            // Center content
            VStack(spacing: 4) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundColor(gaugeColor)

                Text(pressureLevel.rawValue)
                    .font(.system(size: size * 0.09, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    MemoryGaugeView(percentage: 72.5, pressureLevel: .normal)
}
