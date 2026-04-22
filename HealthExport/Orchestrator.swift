import Foundation
import Combine

@MainActor
final class Orchestrator: ObservableObject {
    private let healthStore = HealthStore()
    private let exporter = Exporter()

    @Published var lastRunStatus: String = "Not run yet"
    @Published var lastFileURL: URL?
    @Published var isRunning = false

    func requestAuthAndExportYesterday() async {
        isRunning = true
        defer { isRunning = false }

        do {
            try await healthStore.requestAuthorization()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let snapshot = try await healthStore.snapshot(for: yesterday)
            let url = try exporter.write(snapshot)
            lastFileURL = url
            lastRunStatus = "Success: wrote \(url.lastPathComponent)"
        } catch {
            lastRunStatus = "Failed: \(error.localizedDescription)"
        }
    }

    func requestAuthAndExportToday() async {
        isRunning = true
        defer { isRunning = false }

        do {
            try await healthStore.requestAuthorization()
            let snapshot = try await healthStore.snapshot(for: Date())
            let url = try exporter.write(snapshot)
            lastFileURL = url
            lastRunStatus = "Success: wrote \(url.lastPathComponent)"
        } catch {
            lastRunStatus = "Failed: \(error.localizedDescription)"
        }
    }
}
