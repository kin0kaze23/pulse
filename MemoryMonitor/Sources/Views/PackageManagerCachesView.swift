//
//  PackageManagerCachesView.swift
//  Pulse
//
//  Beautiful UI for package manager cache management
//  This is the #1 differentiator - no other Mac optimizer has this
//

import SwiftUI

// MARK: - Package Manager Caches View

/// Premium view showing all package manager caches with one-click cleanup
struct PackageManagerCachesView: View {
    @ObservedObject var service = PackageManagerCacheService.shared
    @State private var selectedCaches: Set<UUID> = []
    @State private var showCleanConfirmation = false
    @State private var lastCleanedMB: Double = 0
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header with total
            headerCard
            
            // Caches list
            if service.isScanning && service.caches.isEmpty {
                scanningView
            } else if service.caches.isEmpty {
                emptyView
            } else {
                cachesList
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .onAppear {
            if service.caches.isEmpty {
                service.scanAll()
            }
        }
        .alert("Clean Selected Caches?", isPresented: $showCleanConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                performCleanup()
            }
        } message: {
            let total = selectedCaches.compactMap { id in
                service.caches.first { $0.id == id }?.sizeMB
            }.reduce(0, +)
            Text("This will free \(formatSize(total)). This action cannot be undone.")
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                Text("Package Manager Caches")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                
                HStack(spacing: 16) {
                    statPill(value: service.cachesFound, label: "found", color: .blue)
                    statPill(value: service.totalRecoverableMB, label: "recoverable", color: .green, isSize: true)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    service.scanAll()
                } label: {
                    Image(systemName: service.isScanning ? "arrow.clockwise" : "arrow.clockwise")
                        .rotationEffect(.degrees(service.isScanning ? 360 : 0))
                        .animation(service.isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: service.isScanning)
                }
                .buttonStyle(.bordered)
                .disabled(service.isScanning)
                
                if !selectedCaches.isEmpty {
                    Button {
                        showCleanConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clean Selected")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func statPill(value: Int, label: String, color: Color, isSize: Bool = false) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            if isSize {
                Text(formatSize(Double(value)))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            } else {
                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    private func statPill(value: Double, label: String, color: Color, isSize: Bool = true) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(formatSize(value))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView(value: service.scanProgress) {
                Text("Scanning package manager caches...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .progressViewStyle(.linear)
            
            Text("\(Int(service.scanProgress * 100))% complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("All Clean!")
                .font(.system(.title3, design: .rounded, weight: .bold))
            
            Text("No package manager caches found")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Caches List
    
    private var cachesList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                // Group by category
                ForEach(PackageManagerCache.CacheCategory.allCases, id: \.self) { category in
                    if let caches = service.cachesByCategory[category], !caches.isEmpty {
                        categorySection(category: category, caches: caches)
                    }
                }
            }
        }
    }
    
    private func categorySection(category: PackageManagerCache.CacheCategory, caches: [PackageManagerCache]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Category header
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(category.color)
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                Spacer()
                
                let categoryTotal = caches.reduce(0) { $0 + $1.sizeMB }
                Text(formatSize(categoryTotal))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            
            // Caches
            ForEach(caches) { cache in
                CacheRowView(
                    cache: cache,
                    isSelected: selectedCaches.contains(cache.id),
                    onToggle: {
                        if selectedCaches.contains(cache.id) {
                            selectedCaches.remove(cache.id)
                        } else {
                            selectedCaches.insert(cache.id)
                        }
                    },
                    onClean: {
                        let cleaned = service.clean(cache: cache)
                        if cleaned > 0 {
                            lastCleanedMB = cleaned
                            showSuccess = true
                        }
                    }
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helpers
    
    private func formatSize(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
    
    private func performCleanup() {
        let toClean = service.caches.filter { selectedCaches.contains($0.id) }
        let cleaned = service.clean(caches: toClean)
        lastCleanedMB = cleaned
        selectedCaches.removeAll()
        showSuccess = true
    }
}

// MARK: - Cache Row View

struct CacheRowView: View {
    let cache: PackageManagerCache
    let isSelected: Bool
    let onToggle: () -> Void
    let onClean: () -> Void
    
    @State private var isHovered = false
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: DesignSystem.Spacing.md) {
                // Selection checkbox with safety indicator
                Button {
                    onToggle()
                } label: {
                    ZStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? cache.safetyLevel.color : .gray)
                        
                        // Safety checkmark for safe items
                        if cache.safetyLevel == .safe && !isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green.opacity(0.5))
                                .offset(y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(cache.safetyLevel.recommendation)
                
                // Icon with safety glow
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cache.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: cache.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(cache.color)
                    
                    // Safety indicator corner
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: cache.safetyLevel.icon)
                                .font(.system(size: 8))
                                .foregroundColor(cache.safetyLevel.color)
                                .padding(2)
                        }
                        Spacer()
                    }
                }
                .frame(width: 36, height: 36)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cache.displayName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        
                        // Safety badge
                        safetyBadge
                    }
                    
                    Text(cache.description)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Size
                VStack(alignment: .trailing, spacing: 2) {
                    Text(cache.sizeText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(cache.statusColor)
                    
                    if cache.sizeMB > 100 {
                        Text("high")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(cache.statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(cache.statusColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                
                // Expand details button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDetails.toggle()
                    }
                } label: {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }
            .padding(DesignSystem.Spacing.sm)
            
            // Expandable details panel
            if showDetails {
                cacheDetailsPanel
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .fill(isSelected ? cache.safetyLevel.color.opacity(0.08) : (isHovered ? Color.primary.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .stroke(cache.safetyLevel == .verify ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Safety Badge
    
    private var safetyBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: cache.safetyLevel.icon)
                .font(.system(size: 9))
            Text(cache.safetyLevel.rawValue)
                .font(.system(size: 9, weight: .medium, design: .rounded))
        }
        .foregroundColor(cache.safetyLevel.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(cache.safetyLevel.color.opacity(0.12))
        .cornerRadius(4)
    }
    
    // MARK: - Details Panel
    
    private var cacheDetailsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // What happens when cleaned
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("When cleaned:")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    
                    Text(cache.cleanImpact.willRegenerate ? 
                         "Will regenerate \(cache.cleanImpact.regenerationTime.lowercased())" :
                         "Will not regenerate automatically")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Side effects
            if !cache.cleanImpact.sideEffects.isEmpty {
                ForEach(cache.cleanImpact.sideEffects, id: \.self) { effect in
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text(effect)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // What you lose
            if let lose = cache.cleanImpact.whatYouLose {
                HStack(spacing: 8) {
                    Image(systemName: "trash.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text(lose)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            // Warning message
            if let warning = cache.warningMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            
            // Quick clean button
            if cache.sizeMB > 0 {
                Button {
                    onClean()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("Clean This Cache")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(cache.safetyLevel == .verify ? .secondary : .red)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Preview

#Preview {
    PackageManagerCachesView()
        .frame(width: 450, height: 600)
}