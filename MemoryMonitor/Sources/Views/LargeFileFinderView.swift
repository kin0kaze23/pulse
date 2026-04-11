import SwiftUI

/// Large File Finder View
struct LargeFileFinderView: View {
    @StateObject private var finder = LargeFileFinder.shared

    @State private var selectedFiles: Set<UUID> = []
    @State private var sortOption: LargeFileSortOption = .sizeDescending
    @State private var showDeleteConfirmation: Bool = false
    @State private var fileToDelete: LargeFileScanResult?
    @State private var searchText: String = ""
    @State private var filterCategory: FileCategory?

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            controlsSection

            if finder.isScanning {
                scanningProgressSection
            } else if finder.scanResults.isEmpty {
                emptyStateSection
            } else {
                resultsListSection
            }

            if let stats = finder.scanStatistics {
                statisticsSection(stats: stats)
            }
        }
        .padding()
        .alert("Delete File?", isPresented: $showDeleteConfirmation) {
            Button("Move to Trash", role: .destructive) {
                if let file = fileToDelete {
                    _ = finder.deleteFile(file, moveToTrash: true)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to move \"\(file.name)\" to the Trash?")
            }
        }
        .onAppear {
            finder.configuration.minimumSizeMB = 100 // Default 100MB
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Large File Finder")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            if finder.isScanning {
                Button("Cancel") {
                    finder.cancelScan()
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: { finder.startScan() }) {
                    Label("Scan", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(finder.isScanning)
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 200)

            // Category filter
            Picker("Category", selection: $filterCategory) {
                Text("All Categories").tag(nil as FileCategory?)
                ForEach(FileCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category as FileCategory?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)

            Spacer()

            // Sort option
            Picker("Sort", selection: $sortOption) {
                ForEach(LargeFileSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: sortOption) { _, newValue in
                finder.sortResults(by: newValue)
            }
        }
    }

    private var scanningProgressSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(finder.scanProgress.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyStateSection: some View {
        ContentUnavailableView(
            "No Large Files Found",
            systemImage: "doc.text.magnifyingglass",
            description: Text("Click Scan to find large files on your system")
        )
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var resultsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredFiles) { file in
                    LargeFileRow(
                        file: file,
                        isSelected: selectedFiles.contains(file.id),
                        onSelect: {
                            if selectedFiles.contains(file.id) {
                                selectedFiles.remove(file.id)
                            } else {
                                selectedFiles.insert(file.id)
                            }
                        },
                        onDelete: {
                            fileToDelete = file
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .frame(minHeight: 200)
    }

    private func statisticsSection(stats: ScanStatistics) -> some View {
        HStack(spacing: 20) {
            Label("\(stats.totalFilesScanned.formatted()) files scanned", systemImage: "doc")
            Label(stats.formattedTotalSize, systemImage: "internaldrive")
            Label(stats.formattedDuration, systemImage: "clock")
            Spacer()
            Label("\(finder.scanResults.count) large files", systemImage: "arrow.up.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Computed Properties

    private var filteredFiles: [LargeFileScanResult] {
        var files = finder.scanResults

        // Apply search filter
        if !searchText.isEmpty {
            files = files.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply category filter
        if let category = filterCategory {
            files = files.filter { $0.category == category }
        }

        return files
    }
}

// MARK: - Large File Row

struct LargeFileRow: View {
    let file: LargeFileScanResult
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            // Category icon
            Image(systemName: file.category.icon)
                .font(.title3)
                .foregroundStyle(Color(file.category.color))
                .frame(width: 24)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(file.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if file.isProtected {
                        Image(systemName: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(file.parentDirectory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Size
            Text(file.formattedSize)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // Date
            Text(file.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            // Actions
            if isHovering && !file.isProtected {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preview

#Preview {
    LargeFileFinderView()
        .frame(width: 600, height: 500)
}