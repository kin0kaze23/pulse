import SwiftUI

/// Security & Privacy View - Real-time threat monitoring
struct SecurityView: View {
    @StateObject private var scanner = SecurityScanner.shared
    @State private var selectedItem: SecurityScanner.PersistenceItem?
    @State private var showDisableConfirmation = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header with risk indicator
            riskHeader
                .staggeredEntrance(delay: 0)
            
            // Scanning progress indicator
            if scanner.isScanning {
                scanningProgressView
                    .staggeredEntrance(delay: 0.05)
            }
            
            // Real-time monitoring status
            if !scanner.isScanning {
                monitoringStatus
                    .staggeredEntrance(delay: 0.05)
            }
            
            // FDA hint
            if !scanner.isScanning && !scanner.hasTCCAccess {
                fdaHint
                    .staggeredEntrance(delay: 0.07)
            }
            
            // Recent threats
            if !scanner.recentThreats.isEmpty && !scanner.isScanning {
                recentThreatsSection
                    .staggeredEntrance(delay: 0.1)
            }
            
            // Warnings section
            if !scanner.securityWarnings.isEmpty && !scanner.isScanning {
                warningsSection
                    .staggeredEntrance(delay: 0.15)
            }
            
            // Keylogger status
            if !scanner.isScanning {
                keyloggerStatus
                    .staggeredEntrance(delay: 0.2)
            }
            
            // Persistence items
            if !scanner.isScanning {
                persistenceItemsSection
                    .staggeredEntrance(delay: 0.25)
            }
            
            // Deep Security Scan Section
            if !scanner.isScanning {
                deepSecuritySection
                    .staggeredEntrance(delay: 0.30)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .onAppear {
            // Don't auto-start monitoring - let user control it
            // Only run initial scan if no data
            if scanner.persistenceItems.isEmpty && !scanner.isScanning {
                scanner.scan()
            }
        }
        .alert("Disable Item?", isPresented: $showDisableConfirmation) {
            Button("Cancel", role: .cancel) { selectedItem = nil }
            Button("Disable", role: .destructive) {
                if let item = selectedItem {
                    _ = scanner.disableItem(item)
                    scanner.scan()
                }
                selectedItem = nil
            }
        } message: {
            if let item = selectedItem {
                Text("This will unload '\(item.name)' from startup. You can re-enable it later in System Settings.")
            }
        }
    }
    
    // MARK: - Scanning Progress View
    
    private var scanningProgressView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Animated scanning icon
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: scanner.scanProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: scanner.scanProgress)
                
                Image(systemName: "shield.checkered")
                    .font(.title)
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text(scanner.scanPhase.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                
                Text(scanner.scanPhase.estimatedTime)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * scanner.scanProgress)
                            .animation(.easeInOut(duration: 0.3), value: scanner.scanProgress)
                    }
                }
                .frame(height: 8)
                
                // Percentage
                Text("\(Int(scanner.scanProgress * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Risk Header
    
    private var riskHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Risk gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: riskProgress)
                    .stroke(
                        riskColor.gradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Image(systemName: riskIcon)
                        .font(.system(size: 24))
                        .foregroundColor(riskColor)
                    Text(scanner.overallRisk.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(riskColor)
                }
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Security & Privacy")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                
                Text(riskDescription)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                
                Button {
                    scanner.scan()
                } label: {
                    HStack(spacing: 6) {
                        if scanner.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(scanner.isScanning ? "Scanning..." : "Rescan")
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .buttonStyle(.bordered)
                .disabled(scanner.isScanning)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(scanner.persistenceItems.count)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Items Found")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Monitoring Status
    
    private var monitoringStatus: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Monitoring indicator
            ZStack {
                Circle()
                    .fill(scanner.isMonitoring ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                if scanner.isMonitoring {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "shield.slash")
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(scanner.isMonitoring ? "Real-Time Protection Active" : "Protection Paused")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                
                if scanner.isMonitoring {
                    Text("Monitoring for new threats every 60 seconds")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Enable monitoring for continuous protection")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { scanner.monitoringEnabled },
                set: { enabled in
                    if enabled {
                        scanner.startRealTimeMonitoring()
                    } else {
                        scanner.stopRealTimeMonitoring()
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(scanner.isMonitoring ? Color.green.opacity(0.08) : Color.gray.opacity(0.08))
        )
    }
    
    // MARK: - FDA Hint
    
    private var fdaHint: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "key.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Grant Full Disk Access")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("Enable deeper security scans by granting Full Disk Access in System Settings → Privacy & Security")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Open") {
                scanner.openSystemPreferencesSecurity()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .foregroundColor(.orange)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(Color.orange.opacity(0.05))
        )
    }
    
    // MARK: - Recent Threats
    
    private var recentThreatsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("🔔 RECENT THREATS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                    .tracking(1)
                
                Spacer()
                
                if !scanner.recentThreats.isEmpty {
                    Button("Clear") {
                        scanner.clearRecentThreats()
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
            
            ForEach(scanner.recentThreats.prefix(5)) { threat in
                ThreatEventRow(event: threat)
            }
            
            if scanner.recentThreats.count > 5 {
                Text("+ \(scanner.recentThreats.count - 5) more events")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(Color.red.opacity(0.05))
        )
    }
    
    // MARK: - Warnings Section
    
    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("⚠️ SECURITY WARNINGS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.orange)
                .tracking(1)
            
            ForEach(scanner.securityWarnings.prefix(5)) { warning in
                WarningRow(warning: warning) {
                    if let path = warning.itemPath {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
            }
            
            if scanner.securityWarnings.count > 5 {
                Text("+ \(scanner.securityWarnings.count - 5) more warnings")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(Color.orange.opacity(0.08))
        )
    }
    
    // MARK: - Keylogger Status
    
    private var keyloggerStatus: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "keyboard.fill")
                .font(.title2)
                .foregroundColor(keyloggerColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Event Monitoring")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(scanner.keyloggerRisk.rawValue)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(keyloggerColor)
                
                // Permission hint
                if scanner.keyloggerRisk == .none {
                    Text("Grant Full Disk Access for complete detection")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if scanner.keyloggerRisk != .none {
                Button("Review") {
                    scanner.openSystemPreferencesSecurity()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            } else {
                Button("Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(keyloggerColor.opacity(0.08))
        )
    }
    
// MARK: - Persistence Items
    
    private var persistenceItemsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Startup & Persistence Items")
                .font(.system(.headline, design: .rounded))
            
            // Group by type
            persistenceItemsList
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var persistenceItemsList: some View {
        let types = Array(groupedItems.keys.sorted())
        return ForEach(types, id: \.self) { type in
            if let items = groupedItems[type], !items.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Image(systemName: typeIcon(type))
                            .foregroundColor(typeColor(type))
                        Text(type)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("(\(items.count))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(items.prefix(10)) { item in
                        PersistenceItemRow(item: item) {
                            selectedItem = item
                            showDisableConfirmation = true
                        }
                    }
                    
                    if items.count > 10 {
                        Text("+ \(items.count - 10) more items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 28)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color.primary.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Deep Security Section
    
    @State private var showDeepSecurity = false
    
    private var deepSecuritySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Deep Security Scan")
                    .font(.system(.headline, design: .rounded))
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDeepSecurity.toggle()
                    }
                } label: {
                    Image(systemName: showDeepSecurity ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if showDeepSecurity {
                SecurityEnhancementsView()
                    .frame(height: 400)
            } else {
                HStack(spacing: 16) {
                    deepScanHint(icon: "puzzlepiece.extension", text: "Browser Extensions")
                    deepScanHint(icon: "clock", text: "Cron Jobs")
                    deepScanHint(icon: "checkmark.seal", text: "Code Signing")
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func deepScanHint(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers
    
    private var groupedItems: [String: [SecurityScanner.PersistenceItem]] {
        Dictionary(grouping: scanner.persistenceItems) { $0.type.rawValue }
    }
    
    private var riskColor: Color {
        switch scanner.overallRisk {
        case .unknown: return .gray
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private var riskProgress: Double {
        switch scanner.overallRisk {
        case .unknown: return 0
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
    
    private var riskIcon: String {
        switch scanner.overallRisk {
        case .unknown: return "questionmark.shield"
        case .low: return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    private var riskDescription: String {
        switch scanner.overallRisk {
        case .unknown: return "Run a scan to check your security status"
        case .low: return "Your Mac appears secure with no major issues detected"
        case .medium: return "Some items need your attention"
        case .high: return "Potential security risks detected - review warnings below"
        case .critical: return "Critical security issues detected - take action immediately"
        }
    }
    
    private var keyloggerColor: Color {
        switch scanner.keyloggerRisk {
        case .none: return .green
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    private func typeIcon(_ type: String) -> String {
        switch type {
        case "Launch Agent": return "person.fill"
        case "Launch Daemon": return "gearshape.2.fill"
        case "Login Item": return "rectangle.bottomhalf.inset.filled"
        case "System Extension": return "puzzlepiece.extension.fill"
        default: return "doc.fill"
        }
    }
    
    private func typeColor(_ type: String) -> Color {
        switch type {
        case "Launch Agent": return .blue
        case "Launch Daemon": return .purple
        case "Login Item": return .cyan
        case "System Extension": return .orange
        default: return .gray
        }
    }
}

// MARK: - Warning Row

struct WarningRow: View {
    let warning: SecurityScanner.SecurityWarning
    let onShowInFinder: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: warning.severity.icon)
                .foregroundColor(warningColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(warning.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(warning.detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if warning.itemPath != nil {
                Button("Show") {
                    onShowInFinder()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var warningColor: Color {
        switch warning.severity {
        case .info: return .blue
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Threat Event Row

struct ThreatEventRow: View {
    let event: SecurityScanner.SecurityEvent
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Type icon
            Image(systemName: typeIcon)
                .foregroundColor(severityColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                HStack(spacing: 4) {
                    Text(event.detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let path = event.path {
                Button {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(severityColor.opacity(0.05))
        )
    }
    
    private var typeIcon: String {
        switch event.type {
        case .newPersistence: return "plus.shield"
        case .modifiedPersistence: return "pencil.circle"
        case .suspiciousProcess: return "exclamationmark.triangle"
        case .keyloggerDetected: return "keyboard"
        case .networkAnomaly: return "network.slash"
        }
    }
    
    private var severityColor: Color {
        switch event.severity {
        case .info: return .blue
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private var timeAgo: String {
        let interval = Date().timeIntervalSince(event.timestamp)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Persistence Item Row

struct PersistenceItemRow: View {
    let item: SecurityScanner.PersistenceItem
    let onDisable: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                
                if let reason = item.suspicionReason {
                    Text(reason)
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                } else if item.memoryImpactMB > 0 {
                    Text(String(format: "%.0f MB active", item.memoryImpactMB))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Apple badge
            if item.isApple {
                Text("Apple")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            } else if item.canDisable {
                Button {
                    onDisable()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(item.isSuspicious ? Color.orange.opacity(0.05) : Color.clear)
        )
    }
    
    private var statusColor: Color {
        if item.isSuspicious { return .orange }
        if item.isApple { return .green }
        if item.memoryImpactMB > 100 { return .yellow }
        return .blue
    }
}

#Preview {
    SecurityView()
        .frame(width: 500, height: 600)
}