import SwiftUI

/// MemoryMonitor Design System
/// 
/// Principles:
/// - Jony Ive inspired: functional beauty, purposeful animations, breathing life into interface
/// - Consistent spacing, typography, and visual hierarchy
/// - Semantic color assignments that convey meaning
/// - Purposeful animations that aid comprehension
enum DesignSystem {
    
    // MARK: - Spacing Scale
    /// Consistent spacing using a 4pt grid system
    /// Inspired by human interface scaling for visual harmony
    enum Spacing {
        static let xs: CGFloat = 4      // Compact elements
        static let sm: CGFloat = 8      // Between small elements
        static let md: CGFloat = 16     // Standard padding/margins
        static let lg: CGFloat = 24     // Section divisions
        static let xl: CGFloat = 32     // Major layout divisions
        static let xxl: CGFloat = 48    // Super sections
        
        // Legacy aliases for compatibility
        static let tight: CGFloat = 4
        static let standard: CGFloat = 8
        static let relaxed: CGFloat = 16
        static let loose: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    /// Semantic corner radii for consistent shape treatment
    /// Enables cohesive visual language across components
    enum Radius {
        static let small: CGFloat = 8      // Buttons, chips, small controls
        static let medium: CGFloat = 12    // Cards, inputs, medium controls  
        static let large: CGFloat = 16     // Hero cards, panels
        static let xlarge: CGFloat = 24    // Major sections, dialog containers
        static let circular: CGFloat = 9999 // Full circles
    }
    
    // MARK: - Icon Sizes
    /// Harmonized icon sizing that works with typography hierarchy
    /// Ensures visual balance between interface elements and symbols
    enum Icon {
        static let tiny: CGFloat = 14      // Inline with text
        static let small: CGFloat = 16      // Small buttons, toolbar icons
        static let medium: CGFloat = 20     // Standard list items
        static let large: CGFloat = 24      // Section headers
        static let xlarge: CGFloat = 32     // Major buttons, large cards
        static let hero: CGFloat = 48      // Primary actions, hero elements
    }
    
    // MARK: - Gauge Line Widths
    /// Harmonized stroke widths for consistent gauge presentation
    enum GaugeLineWidth {
        static let thin: CGFloat = 6       // Mini gauges, small spaces
        static let medium: CGFloat = 10    // Standard visualization
        static let thick: CGFloat = 14     // Emphasized gauges
    }
    
    // MARK: - Typography
    /// Semantic typography that reinforces visual hierarchy
    /// Uses SF Rounded for premium, contemporary feel
    enum Typography {
        static let headline: Font = .system(.headline, design: .rounded, weight: .semibold)
        static let subheadline: Font = .system(.subheadline, design: .rounded, weight: .medium)
        static let body: Font = .system(.body, design: .rounded)
        static let caption: Font = .system(.caption, design: .rounded)
        static let caption2: Font = .system(.caption2, design: .rounded)
        static let footnote: Font = .system(.footnote, design: .rounded)
    }
    
    // MARK: - Animation Presets
    /// Curated animation presets with purpose and meaning
    /// All animations designed to improve perception and user understanding
    enum Animation {
        static let micro = SwiftUI.Animation.spring(response: 0.15, dampingFraction: 0.8)
            .speed(1.2) // Subtle interactions
        static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
            .speed(1.0) // General transitions
        static let emphasis = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
            .speed(1.0) // Highlighted interactions 
        static let entrance = SwiftUI.Animation.easeOut(duration: 0.4)
            .speed(1.0) // Component appear animations
        static let quick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.9)
            .speed(1.2) // Fast responses
    }
    
    // MARK: - Colors
    /// Semantic colors that convey status, intent, and meaning
    /// Used consistently throughout the app for visual clarity
    enum Colors {
        static let success = Color.green
        static let warning = Color.orange
        static let critical = Color.red
        static let info = Color.blue
        
        // Semantic colors for health scores (0-100)
        /// Maps health scores (0-100) to appropriate semantic colors
        /// Green = Excellent health (90-100), Red = Poor health (0-49)
        static func score(_ value: Int) -> Color {
            switch value {
            case 90...100: return .green    // Healthy
            case 80..<90: return .blue      // Good 
            case 70..<80: return .yellow    // Fair
            case 50..<70: return .orange    // Warning
            default: return .red            // Critical
            }
        }
        
        // Semantic colors for battery percentage
        /// Maps battery percentage and charging state to appropriate colors
        /// Charging appears as Green, low battery as Red for accessibility
        static func battery(_ percentage: Double, isCharging: Bool = false) -> Color {
            if isCharging { return .green }
            if percentage > 20 { return .green }
            return .red  // Low battery warning
        }
        
        // Background opacities for depth and hierarchy
        static let cardBackground = Color.primary.opacity(0.04)
        static let hoverBackground = Color.primary.opacity(0.06)
        static let activeBackground = Color.primary.opacity(0.08)
        static let borderColor = Color.primary.opacity(0.08)
        
        // Material alternatives
        static let ultraThinMaterial = Color.clear
    }
    
    // MARK: - Shadows
    /// Semantic shadow presets for visual depth and hierarchy
    enum Shadow {
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(4), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(8), y: CGFloat(4))
        static let large = (color: Color.black.opacity(0.2), radius: CGFloat(16), y: CGFloat(8))
    }
    
    // MARK: - Button Styles
    /// Consistent touch targets and padding for usability
    enum Button {
        static let primaryPadding = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        static let secondaryPadding = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        static let iconPadding: CGFloat = 8
    }
}

// MARK: - Design System View Modifiers

struct PremiumCardModifier: ViewModifier {
    var padding: CGFloat = DesignSystem.Spacing.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous))
    }
}

struct PremiumButtonStyle: ButtonStyle {
    var isProminent: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.subheadline)
            .padding(DesignSystem.Button.primaryPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                    .fill(isProminent ? Color.accentColor : Color.primary.opacity(0.08))
            )
            .foregroundColor(isProminent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.micro, value: configuration.isPressed)
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(isHovered ? DesignSystem.Colors.hoverBackground : Color.clear)
            .animation(DesignSystem.Animation.micro, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extensions

extension View {
    func premiumCard(padding: CGFloat = DesignSystem.Spacing.lg) -> some View {
        modifier(PremiumCardModifier(padding: padding))
    }
    
    func hoverEffect() -> some View {
        modifier(HoverEffectModifier())
    }
}

// MARK: - Staggered Entrance Animation

struct StaggeredEntranceModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                withAnimation(DesignSystem.Animation.entrance.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredEntrance(delay: Double = 0) -> some View {
        modifier(StaggeredEntranceModifier(delay: delay))
    }
}

// MARK: - Pulse Animation Modifier

struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isActive ? 1.05 : 1.0)
            .opacity(isPulsing && isActive ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

// MARK: - Gauge Configuration

struct GaugeConfiguration {
    var lineWidth: CGFloat
    var startAngle: Double
    var endAngle: Double
    
    static let standard = GaugeConfiguration(
        lineWidth: DesignSystem.GaugeLineWidth.medium,
        startAngle: -90,
        endAngle: 270
    )
    
    static let thin = GaugeConfiguration(
        lineWidth: DesignSystem.GaugeLineWidth.thin,
        startAngle: -90,
        endAngle: 270
    )
    
    static let thick = GaugeConfiguration(
        lineWidth: DesignSystem.GaugeLineWidth.thick,
        startAngle: -90,
        endAngle: 270
    )
}
