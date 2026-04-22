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
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        await run(for: yesterday)
    }

    func requestAuthAndExportToday() async {
        await run(for: Date())
    }

    private func run(for day: Date) async {
        isRunning = true
        defer { isRunning = false }

        do {
            try await healthStore.requestAuthorization()
            let snapshot = try await healthStore.snapshot(for: day)
            let result = try exporter.write(snapshot)
            lastFileURL = result.url
            let storage = result.isICloud ? "iCloud" : "local fallback"
            lastRunStatus = "Success (\(storage)): \(result.url.lastPathComponent)"
        } catch {
            lastRunStatus = "Failed: \(error.localizedDescription)"
        }
    }
}
