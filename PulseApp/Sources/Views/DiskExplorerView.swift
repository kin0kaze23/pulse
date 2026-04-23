//
//  DiskExplorerView.swift
//  Pulse
//
//  Disk Explorer interface with tree-map visualizations and drill-down navigation
//

import SwiftUI

struct DiskExplorerView: View {
    @StateObject private var service = DiskExplorerService.shared
    @State private var breadcrumbs: [DiskFolder] = []
    
    // Current folder state
    @State private var currentFolder: DiskFolder?
    @State private var allFolders: [DiskFolder] = []
    @State private var allFiles: [DiskFolder.DiskFile] = []
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            
            if service.isAnalyzing {
                progressSection
            } else if let folder = currentFolder ?? service.rootFolder {
                contentSection(for: folder)
            } else {
                emptyState
            }
        }
        .padding(20)
        .onAppear {
            if let root = service.rootFolder {
                setCurrentFolder(root)
            }
        }
        .onChange(of: service.rootFolder) { _, folder in
            if folder != nil && currentFolder == nil {
                setCurrentFolder(folder!)
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "internaldrive")
                        .font(.title2)
                        .foregroundColor(.indigo)
                    Text("Disk Explorer")
                        .font(.system(size: 24, weight: .bold))
                }
                
                Text("Explore your disk space with tree-map visualization")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                // Selected path picker
                Picker("Drive", selection: $service.selectedRootPath) {
                    Text("Main Drive").tag("/")
                    Text("Home Folder").tag(FileManager.default.homeDirectoryForCurrentUser.path)
                    // Add additional drives if available
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
                
                if service.isAnalyzing {
                    ProgressView()
                        .controlSize(.small)
                    Text(service.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Refresh") {
                    service.startAnalysis()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text(service.statusMessage)
                .font(.headline)
            
            ProgressView(value: service.analysisProgress, total: 1.0)
                .frame(width: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No disk analysis yet")
                .font(.headline)
            
            Text("Select a drive and click Refresh to begin analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Analyze Root Drive") {
                service.selectedRootPath = "/"
                service.startAnalysis()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func contentSection(for folder: DiskFolder) -> some View {
        VStack(spacing: 16) {
            breadcrumbsSection
            
            HStack(spacing: 24) {
                // Tree map visualization on the left
                treeMapView(for: folder)
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                // Details on the right
                VStack(alignment: .leading, spacing: 12) {
                    folderDetailsSection(for: folder)
                    Divider()
                    largeFilesSection
                }
                .frame(width: 300)
            }
        }
    }
    
    private var breadcrumbsSection: some View {
        HStack {
            ForEach(breadcrumbs.indices, id: \.self) { index in
                let folder = breadcrumbs[index]
                HStack(spacing: 4) {
                    Button(folder.name) {
                        navigateToBreadcrumb(index: index)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    if index != breadcrumbs.count - 1 {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                }
            }
            .font(.system(size: 12, weight: .medium))
            
            Spacer()
        }
        .padding(.bottom, 8)
    }
    
    private func treeMapView(for folder: DiskFolder) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Text("Tree Map View Coming Soon")
                    .font(.headline)
                Spacer()
                
                // Placeholder - this will contain the tree map implementation
                // which is complex and needs a custom algorithm for treemapping rectangles
                Text("Disk usage visualization would appear here")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                Text("Total: \(ByteCountFormatter.string(fromByteCount: folder.sizeBytes, countStyle: .file))")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func folderDetailsSection(for folder: DiskFolder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(folder.name)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                Text("Location: \(folder.path)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(ByteCountFormatter.string(fromByteCount: folder.sizeBytes, countStyle: .file))
                .font(.title2.bold())
                .monospacedDigit()
                .padding(.vertical, 4)
            
            if let modDate = folder.modifiedDate {
                Text("Modified: \(modDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Show top files in this folder
            SubfolderList(subfolders: folder.subfolders.prefix(8).map { $0 })
            
            // Show top files if available
            if !folder.files.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .font(.caption)
                        Text("Top Files")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    VStack(spacing: 2) {
                        ForEach(folder.files.prefix(10).map { $0 }) { file in
                            HStack {
                                Image(systemName: fileTypeIcon(for: file.fileType))
                                    .font(.caption2)
                                    .foregroundColor(fileTypeColor(for: file.fileType))
                                Text(file.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical)
    }
    
    private var largeFilesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle.righthalf.filled")
                    .foregroundColor(.red)
                Text("Large Files")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ScrollView {
                ForEach(service.largeFiles) { file in
                    LargeFileListItem(file: file)
                }
            }
        }
        .frame(maxHeight: 300)
    }
    
    private func fileTypeIcon(for type: FileType) -> String {
        switch type {
        case .document: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .archive: return "archivebox.fill"
        case .code: return "curlybraces"
        case .other: return "doc.plaintext"
        }
    }
    
    private func fileTypeColor(for type: FileType) -> Color {
        switch type {
        case .document: return .blue
        case .image: return .green 
        case .video: return .orange
        case .archive: return .purple
        case .code: return .red
        case .other: return .gray
        }
    }
    
    private func setCurrentFolder(_ folder: DiskFolder) {
        if let currentIndex = breadcrumbs.firstIndex(where: { $0.id == folder.id }) {
            // Going backwards in breadcrumb history
            breadcrumbs.removeSubrange((currentIndex + 1)..<breadcrumbs.count)
        } else {
            // Going forward - add to breadcrumb trail
            breadcrumbs.append(folder)
        }
        currentFolder = folder
        
        // Get direct sub-items for display
        allFolders = folder.subfolders
        allFiles = folder.files
    }
    
    private func navigateToBreadcrumb(index: Int) {
        guard index < breadcrumbs.count else { return }
        currentFolder = breadcrumbs[index]
        breadcrumbs.removeSubrange((index + 1)..<breadcrumbs.count)
    }
}

// MARK: - Supporting Views

struct SubfolderList: View {
    let subfolders: [DiskFolder]
    
    var body: some View {
        if !subfolders.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Subfolders")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.top, 4)
                
                VStack(spacing: 2) {
                    ForEach(subfolders) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(folder.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: folder.sizeBytes, countStyle: .file))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

struct LargeFileListItem: View {
    let file: DiskFolder.DiskFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "doc.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption2)
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
            }
            HStack(spacing: 4) {
                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                Circle()
                    .fill(Color.red)
                    .frame(width: 5, height: 5)
                Text(file.path.components(separatedBy: "/").dropLast().joined(separator: "/"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
            }
            Button("Open Containing Folder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: (file.path as NSString).deletingLastPathComponent)
            }
        }
    }
}

#Preview {
    DiskExplorerView()
}