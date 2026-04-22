import SwiftUI

struct ContentView: View {
    @StateObject private var orch = Orchestrator()

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    Text(orch.lastRunStatus)
                    if let url = orch.lastFileURL {
                        Text("File: \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        Task { await orch.requestAuthAndExportYesterday() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text(orch.isRunning ? "Exporting..." : "Export Yesterday")
                        }
                    }
                    .disabled(orch.isRunning)

                    Button {
                        Task { await orch.requestAuthAndExportToday() }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text(orch.isRunning ? "Exporting..." : "Export Today")
                        }
                    }
                    .disabled(orch.isRunning)
                }
            }
            .navigationTitle("HealthExport")
        }
    }
}

#Preview {
    ContentView()
}
