//
//  BrowserExtensionScanner.swift
//  Pulse
//
//  Scans browser extensions for Safari, Chrome, Firefox
//  Security feature - malware often hides in browser extensions
//

import Foundation
import SwiftUI

// MARK: - Browser Extension Model

struct BrowserExtension: Identifiable {
    let id = UUID()
    let name: String
    let browser: Browser
    let path: String
    let version: String?
    let developer: String?
    let isSigned: Bool
    let isEnabled: Bool
    let riskLevel: RiskLevel
    let permissions: [String]
    
    enum Browser: String, CaseIterable {
        case safari = "Safari"
        case chrome = "Chrome"
        case firefox = "Firefox"
        case edge = "Edge"
        case brave = "Brave"
        
        var icon: String {
            switch self {
            case .safari: return "safari"
            case .chrome: return "globe"
            case .firefox: return "flame"
            case .edge: return "globe"
            case .brave: return "shield"
            }
        }
        
        var color: Color {
            switch self {
            case .safari: return .blue
            case .chrome: return .red
            case .firefox: return .orange
            case .edge: return .blue
            case .brave: return .orange
            }
        }
    }
    
    enum RiskLevel {
        case safe
        case unknown
        case suspicious
        case dangerous
        
        var color: Color {
            switch self {
            case .safe: return .green
            case .unknown: return .gray
            case .suspicious: return .orange
            case .dangerous: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .safe: return "checkmark.shield"
            case .unknown: return "questionmark.shield"
            case .suspicious: return "exclamationmark.shield"
            case .dangerous: return "xmark.shield"
            }
        }
    }
}

// MARK: - Browser Extension Scanner

class BrowserExtensionScanner: ObservableObject {
    static let shared = BrowserExtensionScanner()
    
    @Published var extensions: [BrowserExtension] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var lastScanDate: Date?
    @Published var extensionsByBrowser: [BrowserExtension.Browser: [BrowserExtension]] = [:]
    
    // MARK: - Browser Extension Paths
    
    private let extensionPaths: [BrowserExtension.Browser: [(name: String, path: String, enabledPath: String?)]] = [
        .safari: [
            ("Safari Extensions", "~/Library/Safari/Extensions", nil),
            ("App Extensions", "~/Library/Containers/com.apple.Safari/Data/Library/Safari/AppExtensions", nil)
        ],
        .chrome: [
            ("Chrome Extensions", "~/Library/Application Support/Google/Chrome/Default/Extensions", nil),
            ("Chrome Profiles", "~/Library/Application Support/Google/Chrome/Profile */Extensions", nil)
        ],
        .firefox: [
            ("Firefox Add-ons", "~/Library/Application Support/Firefox/Profiles/*.default*/extensions", nil)
        ],
        .edge: [
            ("Edge Extensions", "~/Library/Application Support/Microsoft Edge/Default/Extensions", nil)
        ],
        .brave: [
            ("Brave Extensions", "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions", nil)
        ]
    ]
    
    // MARK: - Scan
    
    func scan() {
        guard !isScanning else { return }
        
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanProgress = 0
            self.extensions = []
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allExtensions: [BrowserExtension] = []
            let totalBrowsers = Double(BrowserExtension.Browser.allCases.count)
            var completed = 0.0
            
            for browser in BrowserExtension.Browser.allCases {
                let browserExtensions = self.scanBrowser(browser)
                allExtensions.append(contentsOf: browserExtensions)
                completed += 1
                
                DispatchQueue.main.async {
                    self.scanProgress = completed / totalBrowsers
                }
            }
            
            // Group by browser
            let grouped = Dictionary(grouping: allExtensions) { $0.browser }
            
            DispatchQueue.main.async {
                self.extensions = allExtensions.sorted { $0.browser.rawValue < $1.browser.rawValue }
                self.extensionsByBrowser = grouped
                self.lastScanDate = Date()
                self.isScanning = false
                self.scanProgress = 1.0
            }
        }
    }
    
    private func scanBrowser(_ browser: BrowserExtension.Browser) -> [BrowserExtension] {
        var found: [BrowserExtension] = []

        guard let paths = extensionPaths[browser] else { return found }

        for (_, pathTemplate, _) in paths {
            let expandedPath = (pathTemplate as NSString).expandingTildeInPath

            // Handle wildcards
            if pathTemplate.contains("*") {
                // Find matching directories
                let parentPath = (expandedPath as NSString).deletingLastPathComponent
                let pattern = (pathTemplate as NSString).lastPathComponent

                guard let enumerator = FileManager.default.enumerator(atPath: parentPath) else { continue }

                for case let subdir as String in enumerator {
                    if subdir.contains(pattern.replacingOccurrences(of: "*", with: "")) {
                        let fullPath = (parentPath as NSString).appendingPathComponent(subdir)
                        if let exts = scanExtensionDirectory(fullPath, browser: browser) {
                            found.append(contentsOf: exts)
                        }
                    }
                }
                continue
            }

            if let exts = scanExtensionDirectory(expandedPath, browser: browser) {
                found.append(contentsOf: exts)
            }
        }

        return found
    }
    
    private func scanExtensionDirectory(_ path: String, browser: BrowserExtension.Browser) -> [BrowserExtension]? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        
        var extensions: [BrowserExtension] = []
        
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: path)
            
            for item in items {
                let itemPath = (path as NSString).appendingPathComponent(item)
                
                // For Chrome-style extensions, look in version subdirectories
                if browser == .chrome || browser == .edge || browser == .brave {
                    if let versionDirs = try? FileManager.default.contentsOfDirectory(atPath: itemPath) {
                        if let latestVersion = versionDirs.sorted().last {
                            let versionPath = (itemPath as NSString).appendingPathComponent(latestVersion)
                            let manifestPath = (versionPath as NSString).appendingPathComponent("manifest.json")
                            
                            if let ext = parseChromeExtension(
                                id: item,
                                path: itemPath,
                                manifestPath: manifestPath,
                                browser: browser
                            ) {
                                extensions.append(ext)
                            }
                        }
                    }
                } else if browser == .safari {
                    // Safari extensions are .safariextz or app extensions
                    if item.hasSuffix(".safariextz") || item.hasSuffix(".appex") {
                        extensions.append(BrowserExtension(
                            name: item.replacingOccurrences(of: ".safariextz", with: "").replacingOccurrences(of: ".appex", with: ""),
                            browser: browser,
                            path: itemPath,
                            version: nil,
                            developer: nil,
                            isSigned: true, // Safari extensions require signing
                            isEnabled: true,
                            riskLevel: .safe,
                            permissions: []
                        ))
                    }
                } else if browser == .firefox {
                    // Firefox extensions are .xpi
                    if item.hasSuffix(".xpi") {
                        extensions.append(BrowserExtension(
                            name: item.replacingOccurrences(of: ".xpi", with: ""),
                            browser: browser,
                            path: itemPath,
                            version: nil,
                            developer: nil,
                            isSigned: false,
                            isEnabled: true,
                            riskLevel: .unknown,
                            permissions: []
                        ))
                    }
                }
            }
        } catch {
            print("[BrowserExtensionScanner] Error scanning \(path): \(error)")
        }
        
        return extensions.isEmpty ? nil : extensions
    }
    
    private func parseChromeExtension(id: String, path: String, manifestPath: String, browser: BrowserExtension.Browser) -> BrowserExtension? {
        guard let data = FileManager.default.contents(atPath: manifestPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let name = json["name"] as? String ?? id
        let version = json["version"] as? String
        let developer = json["author"] as? String
        
        // Extract permissions
        var permissions: [String] = []
        if let perms = json["permissions"] as? [String] {
            permissions = perms
        }
        
        // Determine risk level based on permissions
        let riskLevel = assessRisk(permissions: permissions)
        
        return BrowserExtension(
            name: name,
            browser: browser,
            path: path,
            version: version,
            developer: developer,
            isSigned: true, // Chrome Web Store extensions are signed
            isEnabled: true,
            riskLevel: riskLevel,
            permissions: permissions
        )
    }
    
    private func assessRisk(permissions: [String]) -> BrowserExtension.RiskLevel {
        let highRiskPermissions = ["tabs", "webRequest", "webRequestBlocking", "cookies", "history", "bookmarks"]
        let dangerousPermissions = ["debugger", "nativeMessaging", "clipboardRead", "clipboardWrite"]
        
        for perm in permissions {
            if dangerousPermissions.contains(perm) {
                return .dangerous
            }
            if highRiskPermissions.contains(perm) {
                return .suspicious
            }
        }
        
        return permissions.isEmpty ? .safe : .unknown
    }
    
    // MARK: - Summary
    
    var totalExtensions: Int { extensions.count }
    var suspiciousCount: Int { extensions.filter { $0.riskLevel == .suspicious || $0.riskLevel == .dangerous }.count }
    var browserCounts: [(browser: BrowserExtension.Browser, count: Int)] {
        BrowserExtension.Browser.allCases.compactMap { browser in
            let count = extensionsByBrowser[browser]?.count ?? 0
            return count > 0 ? (browser, count) : nil
        }
    }
}