//
//  CodeSignVerifier.swift
//  Pulse
//
//  Verifies code signatures for apps and binaries
//  Helps identify unsigned or suspiciously signed applications
//

import Foundation
import SwiftUI

// MARK: - Code Sign Info Model

struct CodeSignInfo: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let signingStatus: SigningStatus
    let authority: String?
    let teamIdentifier: String?
    let identifier: String?
    let isApple: Bool
    let isNotarized: Bool
    
    enum SigningStatus {
        case signed
        case unsigned
        case invalid
        case adHoc
        
        var color: Color {
            switch self {
            case .signed: return .green
            case .unsigned: return .red
            case .invalid: return .orange
            case .adHoc: return .yellow
            }
        }
        
        var icon: String {
            switch self {
            case .signed: return "checkmark.seal.fill"
            case .unsigned: return "xmark.seal"
            case .invalid: return "exclamationmark.triangle.fill"
            case .adHoc: return "seal"
            }
        }
        
        var description: String {
            switch self {
            case .signed: return "Signed"
            case .unsigned: return "Unsigned"
            case .invalid: return "Invalid Signature"
            case .adHoc: return "Ad-Hoc Signed"
            }
        }
    }
}

// MARK: - Code Sign Verifier

class CodeSignVerifier: ObservableObject {
    static let shared = CodeSignVerifier()
    
    @Published var verifiedItems: [CodeSignInfo] = []
    @Published var isVerifying = false
    @Published var verificationProgress: Double = 0
    @Published var lastVerificationDate: Date?
    
    // MARK: - Verify Single Item
    
    func verify(path: String) -> CodeSignInfo? {
        let name = (path as NSString).lastPathComponent
        
        // Run codesign command
        let output = runCodesign(path: path)
        
        return parseCodesignOutput(path: path, name: name, output: output)
    }
    
    // MARK: - Verify Multiple Items
    
    func verify(paths: [String]) {
        guard !isVerifying else { return }
        
        DispatchQueue.main.async {
            self.isVerifying = true
            self.verificationProgress = 0
            self.verifiedItems = []
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var results: [CodeSignInfo] = []
            let total = Double(paths.count)
            
            for (index, path) in paths.enumerated() {
                if let info = self.verify(path: path) {
                    results.append(info)
                }
                
                DispatchQueue.main.async {
                    self.verificationProgress = Double(index + 1) / total
                }
            }
            
            DispatchQueue.main.async {
                self.verifiedItems = results
                self.lastVerificationDate = Date()
                self.isVerifying = false
                self.verificationProgress = 1.0
            }
        }
    }
    
    // MARK: - Verify Launch Agents/Daemons
    
    func verifyPersistenceItems() {
        let paths = collectPersistenceItemPaths()
        verify(paths: paths)
    }
    
    private func collectPersistenceItemPaths() -> [String] {
        var paths: [String] = []
        
        // Launch Agents
        let launchAgentsPaths = [
            "~/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/System/Library/LaunchAgents"
        ]
        
        // Launch Daemons
        let launchDaemonsPaths = [
            "/Library/LaunchDaemons",
            "/System/Library/LaunchDaemons"
        ]
        
        // Scan Launch Agents
        for pathTemplate in launchAgentsPaths {
            let path = (pathTemplate as NSString).expandingTildeInPath
            if let items = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for item in items {
                    if item.hasSuffix(".plist") {
                        // Read plist to get program path
                        let plistPath = (path as NSString).appendingPathComponent(item)
                        if let program = getProgramFromPlist(plistPath: plistPath) {
                            paths.append(program)
                        }
                    }
                }
            }
        }
        
        // Scan Launch Daemons
        for path in launchDaemonsPaths {
            if let items = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for item in items {
                    if item.hasSuffix(".plist") {
                        let plistPath = (path as NSString).appendingPathComponent(item)
                        if let program = getProgramFromPlist(plistPath: plistPath) {
                            paths.append(program)
                        }
                    }
                }
            }
        }
        
        return paths
    }
    
    private func getProgramFromPlist(plistPath: String) -> String? {
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        
        // Get Program key
        if let program = plist["Program"] as? String {
            return program
        }
        
        // Or ProgramArguments first argument
        if let programArgs = plist["ProgramArguments"] as? [String], let first = programArgs.first {
            return first
        }
        
        return nil
    }
    
    // MARK: - Codesign Execution
    
    private func runCodesign(path: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dv", "--verbose=4", path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func parseCodesignOutput(path: String, name: String, output: String) -> CodeSignInfo {
        let lines = output.components(separatedBy: .newlines)
        
        var authority: String?
        var teamIdentifier: String?
        var identifier: String?
        var isAdHoc = false
        
        for line in lines {
            if line.contains("Authority=") {
                authority = line.components(separatedBy: "Authority=").last?.trimmingCharacters(in: .whitespaces)
            }
            if line.contains("TeamIdentifier=") {
                teamIdentifier = line.components(separatedBy: "TeamIdentifier=").last?.trimmingCharacters(in: .whitespaces)
            }
            if line.contains("Identifier=") {
                identifier = line.components(separatedBy: "Identifier=").last?.trimmingCharacters(in: .whitespaces)
            }
            if line.contains("Signature=adhoc") {
                isAdHoc = true
            }
        }
        
        // Determine signing status
        let signingStatus: CodeSignInfo.SigningStatus
        let isApple = authority?.contains("Apple") ?? false
        
        if output.contains("code object is not signed at all") || output.contains("no signature") {
            signingStatus = .unsigned
        } else if isAdHoc {
            signingStatus = .adHoc
        } else if authority != nil {
            signingStatus = .signed
        } else {
            signingStatus = .invalid
        }
        
        // Check notarization (requires different command)
        let isNotarized = checkNotarization(path: path)
        
        return CodeSignInfo(
            path: path,
            name: name,
            signingStatus: signingStatus,
            authority: authority,
            teamIdentifier: teamIdentifier,
            identifier: identifier,
            isApple: isApple,
            isNotarized: isNotarized
        )
    }
    
    private func checkNotarization(path: String) -> Bool {
        // Use spctl to check notarization
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        task.arguments = ["--assess", "--verbose=4", "--type", "execute", path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try? task.run()
        task.waitUntilExit()
        
        // Exit code 0 means accepted (notarized)
        return task.terminationStatus == 0
    }
    
    // MARK: - Summary
    
    var signedCount: Int {
        verifiedItems.filter { $0.signingStatus == .signed }.count
    }
    
    var unsignedCount: Int {
        verifiedItems.filter { $0.signingStatus == .unsigned }.count
    }
    
    var suspiciousCount: Int {
        verifiedItems.filter { $0.signingStatus == .invalid || $0.signingStatus == .adHoc }.count
    }
    
    var appleSignedCount: Int {
        verifiedItems.filter { $0.isApple }.count
    }
}