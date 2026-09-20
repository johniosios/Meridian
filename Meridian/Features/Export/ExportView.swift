import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var folderStore: FolderStore
    @StateObject private var orch = Orchestrator()

    @State private var showingFolderPicker = false
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
    @State private var customEnd: Date = Date()

    private var customDaysCount: Int {
        DateRangeUtil.days(from: customStart, to: customEnd).count
    }

    var body: some View {
        NavigationStack {
            List {
                folderSection
                quickExportSection
                customRangeSection
                recentSection
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderPick(result: result)
            }
        }
    }

    // MARK: - Sections

    private var folderSection: some View {
        Section("Save Location") {
            HStack(spacing: 12) {
                Image(systemName: folderIcon)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(folderStore.displayPath)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                Spacer()
                Button("Change") { showingFolderPicker = true }
                    .disabled(orch.isRunning)
            }
            .padding(.vertical, 4)

            if folderStore.folderURL != nil {
                Button(role: .destructive) {
                    folderStore.clear()
                } label: {
                    Label("Reset to Local Default", systemImage: "arrow.uturn.backward")
                }
            }
        }
    }

    private var folderIcon: String {
        guard let url = folderStore.folderURL else { return "folder" }
        return url.path.contains("Mobile Documents") ? "icloud" : "folder"
    }

    private var quickExportSection: some View {
        Section("Quick Export") {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
                ForEach(DateRangePreset.allCases) { preset in
                    Button {
                        Task { await orch.export(healthStore: healthStore, preset: preset, folder: folderStore.folderURL) }
                    } label: {
                        Text(preset.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(orch.isRunning)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var customRangeSection: some View {
        Section("Custom Range") {
            DatePicker("Start", selection: $customStart, displayedComponents: .date)
            DatePicker("End", selection: $customEnd, in: customStart..., displayedComponents: .date)

            Button {
                Task {
                    await orch.exportRange(
                        healthStore: healthStore,
                        from: customStart,
                        to: customEnd,
                        folder: folderStore.folderURL,
                        label: "Custom \(customDaysCount) days"
                    )
                }
            } label: {
                HStack {
                    Image(systemName: orch.isRunning ? "hourglass" : "square.and.arrow.down")
                    Text(orch.isRunning ? runningLabel : "Export \(customDaysCount) days")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(orch.isRunning || customDaysCount <= 0)
        }
    }

    private var recentSection: some View {
        Section("Recent") {
            if orch.isRunning && orch.progressTotal > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exporting \(orch.progressCurrent)/\(orch.progressTotal)")
                        .font(.subheadline)
                    ProgressView(value: Double(orch.progressCurrent), total: Double(orch.progressTotal))
                }
                .padding(.vertical, 4)
            } else {
                Text(orch.lastRunStatus)
                    .font(.subheadline)
            }
        }
    }

    private var runningLabel: String {
        if orch.progressTotal > 0 {
            return "Exporting \(orch.progressCurrent)/\(orch.progressTotal)"
        }
        return "Exporting..."
    }

    // MARK: - Actions

    private func handleFolderPick(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try folderStore.setFolder(url)
            } catch {
                orch.lastRunStatus = "✗ Failed to select folder: \(error.localizedDescription)"
            }
        case .failure(let error):
            orch.lastRunStatus = "✗ Failed to select folder: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ExportView()
}
