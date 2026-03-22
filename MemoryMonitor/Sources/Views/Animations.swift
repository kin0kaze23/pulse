import SwiftUI
import AppKit

// MARK: - Glass Card (etched border + shadow)

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

// MARK: - Haptic Feedback

enum HapticFeedback {
    static func light() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }

    static func medium() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    static func heavy() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    // Alias for medium - semantic name for success feedback
    static func success() {
        medium()
    }
}

/// Animated gauge ring that pulses when value changes significantly
struct PulseGauge: View {
    let value: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Pulse ring (appears briefly on change)
            if pulse {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: lineWidth + 2)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .opacity(pulse ? 0 : 0.5)
                    .animation(.easeOut(duration: 0.6), value: pulse)
            }

            // Background
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: CGFloat(min(value, 100)) / 100.0)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.6)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: value)
        }
        .frame(width: size, height: size)
        .onChange(of: value) { oldValue, newValue in
            if abs(newValue - oldValue) > 5 {
                withAnimation { pulse = true }
                HapticFeedback.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { pulse = false }
                }
            }
        }
    }
}

/// Success checkmark with spring animation
struct SuccessCheckmark: View {
    let message: String
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16, weight: .medium))
                .scaleEffect(scale)
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .opacity(opacity)
        .onAppear {
            HapticFeedback.success()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let active: Bool
    @Environment(\.controlActiveState) private var controlActiveState

    func body(content: Content) -> some View {
        content
            .overlay(
                active && controlActiveState == .key ? shimmerOverlay : nil
            )
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                .white.opacity(0),
                .white.opacity(0.3),
                .white.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .rotationEffect(.degrees(20))
        .offset(x: phase)
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 300
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func shimmer(active: Bool) -> some View {
        modifier(ShimmerModifier(active: active))
    }
}

// MARK: - The Orb (radical simplification)

struct VitalityOrb: View {
    let healthScore: Int
    let memoryPercent: Double
    let cpuPercent: Double
    @State private var breathe = false
    @State private var rotate = false
    @State private var isAnimating = false
    
    // Track if window is key/visible
    @Environment(\.controlActiveState) private var controlActiveState

    private var orbColor: Color {
        switch healthScore {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }

    private var orbSize: CGFloat {
        // Larger = healthier (memory is low)
        let base: CGFloat = 100
        let bonus = CGFloat(100 - memoryPercent) * 0.4
        return base + bonus
    }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(orbColor.opacity(0.08))
                .frame(width: orbSize + 30, height: orbSize + 30)
                .blur(radius: 15)
                .scaleEffect(breathe ? 1.05 : 0.95)

            // Middle layer — rotating gradient (simplified, no animation)
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            orbColor.opacity(0.3),
                            orbColor.opacity(0.1),
                            orbColor.opacity(0.3),
                        ]),
                        center: .center,
                        angle: .degrees(45)
                    )
                )
                .frame(width: orbSize + 10, height: orbSize + 10)

            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            orbColor.opacity(0.9),
                            orbColor.opacity(0.5),
                            orbColor.opacity(0.2),
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize / 2
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .scaleEffect(breathe ? 1.03 : 0.97)

            // Inner highlight
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: orbSize * 0.3, height: orbSize * 0.3)
                .offset(x: -orbSize * 0.15, y: -orbSize * 0.15)
                .blur(radius: 5)

            // Grade
            Text(healthGrade)
                .font(.system(size: orbSize * 0.35, weight: .ultraLight, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: orbSize + 40, height: orbSize + 40)
        .onAppear {
            startAnimations()
        }
        .onChange(of: controlActiveState) { _, newState in
            // Pause animations when window is inactive
            if newState == .key {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
    }
    
    private func startAnimations() {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            breathe = true
        }
    }
    
    private func stopAnimations() {
        isAnimating = false
        // Animations naturally stop when we don't restart them
    }

    private var healthGrade: String {
        switch healthScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 50..<69: return "D"
        default: return "F"
        }
    }
}

// MARK: - Bento Card

struct BentoCard<Content: View>: View {
    let content: Content
    var color: Color = .clear

    init(color: Color = .clear, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color == .clear ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(color.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}
