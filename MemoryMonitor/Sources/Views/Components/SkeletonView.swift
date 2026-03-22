import SwiftUI

/// Loading skeleton modifier for placeholder content
struct SkeletonModifier: ViewModifier {
    @State private var isAnimating = false
    @Environment(\.controlActiveState) private var controlActiveState

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.04),
                        Color.primary.opacity(0.12),
                        Color.primary.opacity(0.04)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .onAppear {
                guard controlActiveState == .key else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            .onChange(of: controlActiveState) { _, newState in
                if newState == .key {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
            }
    }
}

extension View {
    /// Apply a loading skeleton effect to the view
    func skeleton(isLoading: Bool) -> some View {
        Group {
            if isLoading {
                modifier(SkeletonModifier())
            } else {
                self
            }
        }
    }
}