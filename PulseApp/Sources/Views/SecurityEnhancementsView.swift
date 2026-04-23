//
//  SecurityEnhancementsView.swift
//  Pulse
//
//  Premium UI for Phase 1 security enhancements
//  Browser Extensions, Cron Jobs, Code Signing verification
//

import SwiftUI

// MARK: - Security Enhancements View

struct SecurityEnhancementsView: View {
    @StateObject private var browserScanner = BrowserExtensionScanner.shared
    @StateObject private var cronScanner = CronJobScanner.shared
    @StateObject private var codeSignVerifier = CodeSignVerifier.shared
    
    @State private var selectedTab: SecurityTab = .extensions
    
    enum SecurityTab: String, CaseIterable {
        case extensions = "Extensions"
        case cronJobs = "Cron Jobs"
        case codeSign = "Code Sign"
        
        var icon: String {
            switch self {
            case .extensions: return "puzzlepiece.extension"
            case .cronJobs: return "clock"
            case .codeSign: return "checkmark.seal"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            headerCard
            
            // Tab picker
            tabPicker
            
            // Content
            switch selectedTab {
            case .extensions:
                BrowserExtensionsSection(scanner: browserScanner)
            case .cronJobs:
                CronJobsSection(scanner: cronScanner)
            case .codeSign:
                CodeSignSection(verifier: codeSignVerifier)
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }
    
    // MARK: - Header
    
    private var headerCard: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.3), .orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("Security Deep Scan")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                
                HStack(spacing: 16) {
                    if browserScanner.suspiciousCount > 0 || cronScanner.suspiciousCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(browserScanner.suspiciousCount + cronScanner.suspiciousCount) items need review")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("All clear")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Scan all button
            Button {
                browserScanner.scan()
                cronScanner.scan()
                codeSignVerifier.verifyPersistenceItems()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Scan All")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Tab Picker
    
    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(SecurityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// MARK: - Browser Extensions Section

struct BrowserExtensionsSection: View {
    @ObservedObject var scanner: BrowserExtensionScanner
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if scanner.isScanning {
                scanningView
            } else if scanner.extensions.isEmpty {
                emptyView("No browser extensions found", icon: "puzzlepiece.extension")
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(scanner.extensionsByBrowser.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { browser in
                            if let extensions = scanner.extensionsByBrowser[browser] {
                                browserSection(browser: browser, extensions: extensions)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if scanner.extensions.isEmpty {
                scanner.scan()
            }
        }
    }
    
    private func browserSection(browser: BrowserExtension.Browser, extensions: [BrowserExtension]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: browser.icon)
                    .foregroundColor(browser.color)
                Text(browser.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(extensions.count) extensions")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            ForEach(extensions) { ext in
                extensionRow(ext)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func extensionRow(_ ext: BrowserExtension) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: ext.riskLevel.icon)
                .foregroundColor(ext.riskLevel.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ext.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                if !ext.permissions.isEmpty {
                    Text(ext.permissions.prefix(3).joined(separator: ", "))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if ext.riskLevel == .dangerous || ext.riskLevel == .suspicious {
                Text(ext.riskLevel == .dangerous ? "High Risk" : "Caution")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(ext.riskLevel.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ext.riskLevel.color.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Scanning browser extensions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func emptyView(_ message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Cron Jobs Section

struct CronJobsSection: View {
    @ObservedObject var scanner: CronJobScanner
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if scanner.isScanning {
                scanningView
            } else if scanner.jobs.isEmpty {
                emptyView("No cron jobs found", icon: "clock")
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(scanner.jobs) { job in
                            cronJobRow(job)
                        }
                    }
                }
            }
        }
        .onAppear {
            if scanner.jobs.isEmpty {
                scanner.scan()
            }
        }
    }
    
    private func cronJobRow(_ job: CronJob) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: job.riskLevel.icon)
                .foregroundColor(job.riskLevel.color)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(job.name)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                    
                    Text(job.source.rawValue)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                }
                
                Text(job.scheduleDescription)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if job.riskLevel == .dangerous || job.riskLevel == .suspicious {
                Text(job.riskLevel == .dangerous ? "Danger" : "Warning")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(job.riskLevel.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(job.riskLevel.color.opacity(0.15))
                    .cornerRadius(4)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Scanning cron jobs...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func emptyView(_ message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Code Sign Section

struct CodeSignSection: View {
    @ObservedObject var verifier: CodeSignVerifier
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Summary
            if !verifier.verifiedItems.isEmpty {
                summaryCard
            }
            
            if verifier.isVerifying {
                scanningView
            } else if verifier.verifiedItems.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .onAppear {
            if verifier.verifiedItems.isEmpty {
                verifier.verifyPersistenceItems()
            }
        }
    }
    
    private var summaryCard: some View {
        HStack(spacing: 16) {
            statItem(count: verifier.signedCount, label: "Signed", color: .green)
            statItem(count: verifier.unsignedCount, label: "Unsigned", color: .red)
            statItem(count: verifier.suspiciousCount, label: "Suspicious", color: .orange)
            statItem(count: verifier.appleSignedCount, label: "Apple", color: .blue)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func statItem(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No persistence items to verify")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("Scan Persistence Items") {
                verifier.verifyPersistenceItems()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(verifier.verifiedItems) { item in
                    codeSignRow(item)
                }
            }
        }
    }
    
    private func codeSignRow(_ item: CodeSignInfo) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: item.signingStatus.icon)
                .foregroundColor(item.signingStatus.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(1)
                
                if let authority = item.authority {
                    Text(authority)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if item.isApple {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                if item.isNotarized {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                
                Text(item.signingStatus.description)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(item.signingStatus.color)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .fill(Color.primary.opacity(0.03))
        )
    }
    
    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Verifying code signatures...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Preview

#Preview {
    SecurityEnhancementsView()
        .frame(width: 500, height: 600)
}