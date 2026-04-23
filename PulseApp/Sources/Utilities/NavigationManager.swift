import SwiftUI
import AppKit

/// Centralized navigation manager for Pulse windows
/// Provides robust window navigation without fragile title matching
final class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    private init() {}
    
    enum Window: String, CaseIterable {
        case dashboard = "dashboard"
        case settings = "settings"
        
        var title: String {
            switch self {
            case .dashboard: return Brand.name
            case .settings: return "Settings"
            }
        }
        
        var identifier: String { rawValue }
    }
    
    /// Find window by our custom identifier
    func findWindow(_ window: Window) -> NSWindow? {
        NSApp.windows.first { nsWindow in
            // Check our custom identifier
            if let identifier = nsWindow.identifier?.rawValue {
                return identifier.contains(window.identifier)
            }
            // Fallback to title matching (less reliable)
            return nsWindow.title.contains(window.title)
        }
    }
    
    /// Navigate to a specific window
    func navigate(to window: Window) {
        NSApp.activate()
        
        if let targetWindow = findWindow(window) {
            targetWindow.makeKeyAndOrderFront(nil)
            if let mainScreen = NSScreen.main {
                let screenFrame = mainScreen.visibleFrame
                let windowSize = targetWindow.frame.size
                let x = screenFrame.midX - windowSize.width / 2
                let y = screenFrame.midY - windowSize.height / 2
                targetWindow.setFrameOrigin(NSPoint(x: x, y: y))
            }
            targetWindow.orderFrontRegardless()
        } else {
            // Window not found, try to open it via notification
            NotificationCenter.default.post(
                name: .openWindow,
                object: nil,
                userInfo: ["window": window.rawValue]
            )
        }
    }
}

extension Notification.Name {
    static let openWindow = Notification.Name("PulseOpenWindow")
}
