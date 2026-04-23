//
//  PackageManagerCacheService.swift
//  Pulse
//
//  Dedicated service for package manager cache detection and cleanup
//  This is the #1 differentiator for Pulse - no other Mac optimizer focuses on developers
//

import Foundation
import Combine
import SwiftUI

// MARK: - Package Manager Cache Model

/// Represents a package manager cache that can be cleaned
struct PackageManagerCache: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let displayName: String
    let path: String
    let icon: String
    let category: CacheCategory
    let color: Color
    let description: String
    let isDestructive: Bool
    let warningMessage: String?
    let safetyLevel: SafetyLevel
    let cleanImpact: CleanImpact
    
    var sizeMB: Double = 0
    var isScanning: Bool = false
    var lastScanned: Date?
    
    var exists: Bool { sizeMB > 0 }
    
    // MARK: - Safety Level
    
    /// How safe is it to clean this cache
    enum SafetyLevel: String {
        case safe = "Safe"
        case caution = "Caution"
        case verify = "Verify First"
        
        var icon: String {
            switch self {
            case .safe: return "checkmark.shield.fill"
            case .caution: return "exclamationmark.shield"
            case .verify: return "questionmark.shield"
            }
        }
        
        var color: Color {
            switch self {
            case .safe: return .green
            case .caution: return .orange
            case .verify: return .yellow
            }
        }
        
        var description: String {
            switch self {
            case .safe: return "Completely safe to clean. Will be regenerated when needed."
            case .caution: return "Safe to clean, but will need to re-download dependencies."
            case .verify: return "Check contents before cleaning. May contain important data."
            }
        }
        
        var recommendation: String {
            switch self {
            case .safe: return "Recommended for cleanup"
            case .caution: return "Clean if you need space"
            case .verify: return "Review before cleaning"
            }
        }
    }
    
    // MARK: - Clean Impact
    
    /// What happens when this cache is cleaned
    struct CleanImpact: Hashable {
        let willRegenerate: Bool
        let regenerationTime: String // e.g., "Instant", "Next build", "Next install"
        let sideEffects: [String]
        let whatYouLose: String?
        
        static let safe = CleanImpact(willRegenerate: true, regenerationTime: "Instant", sideEffects: [], whatYouLose: nil)
        static let rebuild = CleanImpact(willRegenerate: true, regenerationTime: "Next build", sideEffects: ["First build will be slower"], whatYouLose: nil)
        static let reinstall = CleanImpact(willRegenerate: true, regenerationTime: "Next install", sideEffects: ["Packages will re-download"], whatYouLose: nil)
    }
    
    enum CacheCategory: String, CaseIterable {
        case javascript = "JavaScript"
        case python = "Python"
        case go = "Go"
        case rust = "Rust"
        case java = "Java"
        case ruby = "Ruby"
        case php = "PHP"
        case apple = "Apple"
        case dotnet = ".NET"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .javascript: return "curlybraces"
            case .python: return "chevron.left.forwardslash.chevron.right"
            case .go: return "goforward"
            case .rust: return "gearshape.2"
            case .java: return "cup.and.saucer"
            case .ruby: return "gem"
            case .php: return "chevron.left.forwardslash.chevron.right"
            case .apple: return "apple.logo"
            case .dotnet: return "chevron.left.forwardslash.chevron.right"
            case .other: return "folder"
            }
        }
        
        var color: Color {
            switch self {
            case .javascript: return .yellow
            case .python: return .blue
            case .go: return .cyan
            case .rust: return .orange
            case .java: return .red
            case .ruby: return .red
            case .php: return .purple
            case .apple: return .gray
            case .dotnet: return .purple
            case .other: return .gray
            }
        }
    }
    
    var sizeText: String {
        if sizeMB == 0 { return "—" }
        if sizeMB >= 1024 {
            return String(format: "%.1f GB", sizeMB / 1024)
        }
        return String(format: "%.0f MB", sizeMB)
    }
    
    var statusColor: Color {
        if sizeMB == 0 { return .gray }
        if sizeMB >= 1024 { return .red }
        if sizeMB >= 512 { return .orange }
        if sizeMB >= 100 { return .yellow }
        return .green
    }
}

// MARK: - Package Manager Cache Service

/// Service for scanning and cleaning package manager caches
/// This is what makes Pulse unique - developer-first optimization
class PackageManagerCacheService: ObservableObject {
    static let shared = PackageManagerCacheService()
    
    // MARK: - Published Properties
    
    @Published var caches: [PackageManagerCache] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var totalRecoverableMB: Double = 0
    @Published var lastScanDate: Date?
    @Published var scanError: String?
    
    // MARK: - Private Properties
    
    private let workQueue = DispatchQueue(label: "com.pulse.packagemanager", qos: .userInitiated)
    
    // MARK: - Cache Definitions
    
    /// All known package manager caches with safety information
    private let cacheDefinitions: [PackageManagerCache] = [
        // MARK: JavaScript/TypeScript
        PackageManagerCache(
            name: "npm",
            displayName: "npm Cache",
            path: "~/.npm/_cacache",
            icon: "curlybraces",
            category: .javascript,
            color: .red,
            description: "Node package manager cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "yarn",
            displayName: "Yarn Cache",
            path: "~/Library/Caches/Yarn",
            icon: "curlybraces",
            category: .javascript,
            color: .blue,
            description: "Yarn package manager cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "pnpm",
            displayName: "pnpm Store",
            path: "~/Library/pnpm/store",
            icon: "curlybraces",
            category: .javascript,
            color: .orange,
            description: "pnpm package store",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "bun",
            displayName: "Bun Cache",
            path: "~/.bun/install/cache",
            icon: "curlybraces",
            category: .javascript,
            color: .purple,
            description: "Bun runtime cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        
        // MARK: Python
        PackageManagerCache(
            name: "pip",
            displayName: "pip Cache",
            path: "~/Library/Caches/pip",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .python,
            color: .blue,
            description: "Python package cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "poetry",
            displayName: "Poetry Cache",
            path: "~/Library/Caches/pypoetry",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .python,
            color: .cyan,
            description: "Poetry dependency manager cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "conda",
            displayName: "Conda PKGs",
            path: "~/anaconda3/pkgs",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .python,
            color: .green,
            description: "Conda package cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .caution,
            cleanImpact: PackageManagerCache.CleanImpact(willRegenerate: true, regenerationTime: "Next install", sideEffects: ["Packages will re-download"], whatYouLose: "Cached package archives")
        ),
        
        // MARK: Go
        PackageManagerCache(
            name: "go-mod",
            displayName: "Go Modules",
            path: "~/go/pkg/mod/cache",
            icon: "goforward",
            category: .go,
            color: .cyan,
            description: "Go module cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "go-build",
            displayName: "Go Build Cache",
            path: "~/Library/Caches/go-build",
            icon: "goforward",
            category: .go,
            color: .cyan,
            description: "Go build artifacts",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .rebuild
        ),
        
        // MARK: Rust
        PackageManagerCache(
            name: "cargo",
            displayName: "Cargo Registry",
            path: "~/.cargo/registry/cache",
            icon: "gearshape.2",
            category: .rust,
            color: .orange,
            description: "Rust package registry cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "cargo-git",
            displayName: "Cargo Git Cache",
            path: "~/.cargo/git/db",
            icon: "gearshape.2",
            category: .rust,
            color: .orange,
            description: "Rust git dependencies cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        
        // MARK: Java/Kotlin
        PackageManagerCache(
            name: "gradle",
            displayName: "Gradle Cache",
            path: "~/.gradle/caches",
            icon: "cup.and.saucer",
            category: .java,
            color: .green,
            description: "Gradle build cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .rebuild
        ),
        PackageManagerCache(
            name: "maven",
            displayName: "Maven Repository",
            path: "~/.m2/repository",
            icon: "cup.and.saucer",
            category: .java,
            color: .red,
            description: "Maven local repository",
            isDestructive: true,
            warningMessage: "Contains downloaded dependencies - will need to re-download",
            safetyLevel: .caution,
            cleanImpact: PackageManagerCache.CleanImpact(willRegenerate: true, regenerationTime: "Next build", sideEffects: ["All dependencies will re-download"], whatYouLose: "All cached Maven dependencies")
        ),
        
        // MARK: Ruby
        PackageManagerCache(
            name: "gems",
            displayName: "RubyGems Cache",
            path: "~/.gem/cache",
            icon: "gem",
            category: .ruby,
            color: .red,
            description: "Ruby gem cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        PackageManagerCache(
            name: "cocoapods",
            displayName: "CocoaPods Cache",
            path: "~/Library/Caches/CocoaPods",
            icon: "apple.logo",
            category: .apple,
            color: .red,
            description: "iOS dependency cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        
        // MARK: PHP
        PackageManagerCache(
            name: "composer",
            displayName: "Composer Cache",
            path: "~/.composer/cache",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .php,
            color: .purple,
            description: "PHP package cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        
        // MARK: Apple
        PackageManagerCache(
            name: "spm",
            displayName: "Swift PM Cache",
            path: "~/Library/Caches/org.swift.swiftpm",
            icon: "apple.logo",
            category: .apple,
            color: .orange,
            description: "Swift Package Manager cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .rebuild
        ),
        PackageManagerCache(
            name: "carthage",
            displayName: "Carthage Cache",
            path: "~/Library/Caches/org.carthage.CarthageKit",
            icon: "apple.logo",
            category: .apple,
            color: .blue,
            description: "Carthage dependency cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .rebuild
        ),
        
        // MARK: .NET
        PackageManagerCache(
            name: "nuget",
            displayName: "NuGet Cache",
            path: "~/.nuget/packages",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .dotnet,
            color: .blue,
            description: ".NET package cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .reinstall
        ),
        
        // MARK: Build Tools
        PackageManagerCache(
            name: "typescript",
            displayName: "TypeScript Cache",
            path: "~/.cache/typescript",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .javascript,
            color: .blue,
            description: "TypeScript compiler cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .safe
        ),
        PackageManagerCache(
            name: "vite",
            displayName: "Vite Cache",
            path: "~/.vite",
            icon: "bolt",
            category: .javascript,
            color: .purple,
            description: "Vite dev server cache",
            isDestructive: false,
            warningMessage: nil,
            safetyLevel: .safe,
            cleanImpact: .safe
        ),
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public API
    
    /// Scan all package manager caches
    func scanAll() {
        guard !isScanning else { return }
        
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanProgress = 0
            self.scanError = nil
        }
        
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            var scannedCaches: [PackageManagerCache] = []
            var totalMB: Double = 0
            let total = Double(self.cacheDefinitions.count)
            
            for (index, var cache) in self.cacheDefinitions.enumerated() {
                let size = DirectorySizeUtility.quickDirectorySizeMB(cache.path, maxItems: 5000)
                cache.sizeMB = size
                cache.lastScanned = Date()
                scannedCaches.append(cache)
                totalMB += size
                
                // Update progress
                DispatchQueue.main.async {
                    self.scanProgress = Double(index + 1) / total
                }
            }
            
            // Sort by size (largest first)
            scannedCaches.sort { $0.sizeMB > $1.sizeMB }
            
            DispatchQueue.main.async {
                self.caches = scannedCaches
                self.totalRecoverableMB = totalMB
                self.lastScanDate = Date()
                self.isScanning = false
                self.scanProgress = 1.0
            }
        }
    }
    
    /// Scan a specific cache
    func scan(cache: PackageManagerCache) -> PackageManagerCache {
        var updated = cache
        updated.sizeMB = DirectorySizeUtility.quickDirectorySizeMB(cache.path, maxItems: 5000)
        updated.lastScanned = Date()
        return updated
    }
    
    /// Clean a specific cache
    @discardableResult
    func clean(cache: PackageManagerCache) -> Double {
        let path = (cache.path as NSString).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        
        let originalSize = DirectorySizeUtility.quickDirectorySizeMB(path, maxItems: 5000)
        
        do {
            try FileManager.default.removeItem(atPath: path)
            
            // Update caches list
            DispatchQueue.main.async { [weak self] in
                self?.caches.removeAll { $0.id == cache.id }
                self?.totalRecoverableMB -= originalSize
            }
            
            return originalSize
        } catch {
            print("[PackageManagerCacheService] Failed to clean \(cache.name): \(error)")
            return 0
        }
    }
    
    /// Clean multiple caches
    func clean(caches: [PackageManagerCache]) -> Double {
        var totalCleaned: Double = 0
        
        for cache in caches {
            totalCleaned += clean(cache: cache)
        }
        
        return totalCleaned
    }
    
    /// Clean all caches (with optional exclusion list)
    func cleanAll(excluding: [String] = []) -> Double {
        let toClean = caches.filter { !excluding.contains($0.name) && $0.sizeMB > 0 }
        return clean(caches: toClean)
    }
    
    // MARK: - Convenience Properties
    
    /// Caches grouped by category
    var cachesByCategory: [PackageManagerCache.CacheCategory: [PackageManagerCache]] {
        Dictionary(grouping: caches.filter { $0.sizeMB > 0 }) { $0.category }
    }
    
    /// Caches with significant size (> 50MB)
    var significantCaches: [PackageManagerCache] {
        caches.filter { $0.sizeMB > 50 }
    }
    
    /// Total size text
    var totalSizeText: String {
        if totalRecoverableMB >= 1024 {
            return String(format: "%.1f GB", totalRecoverableMB / 1024)
        }
        return String(format: "%.0f MB", totalRecoverableMB)
    }
    
    /// Number of caches found
    var cachesFound: Int {
        caches.filter { $0.sizeMB > 0 }.count
    }
}

// MARK: - Preview Helper

extension PackageManagerCacheService {
    /// Create sample data for previews
    static var preview: PackageManagerCacheService {
        let service = PackageManagerCacheService()
        service.caches = [
            PackageManagerCache(name: "npm", displayName: "npm Cache", path: "~/.npm", icon: "curlybraces", category: .javascript, color: .red, description: "Node package cache", isDestructive: false, warningMessage: nil, safetyLevel: .safe, cleanImpact: .reinstall),
            PackageManagerCache(name: "pip", displayName: "pip Cache", path: "~/Library/Caches/pip", icon: "chevron.left.forwardslash.chevron.right", category: .python, color: .blue, description: "Python package cache", isDestructive: false, warningMessage: nil, safetyLevel: .safe, cleanImpact: .reinstall),
        ]
        service.caches[0].sizeMB = 1500
        service.caches[1].sizeMB = 450
        service.totalRecoverableMB = 1950
        service.lastScanDate = Date()
        return service
    }
}