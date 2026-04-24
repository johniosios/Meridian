import Foundation
import Combine

@MainActor
final class Orchestrator: ObservableObject {
    private let healthStore = HealthStore()
    private let exporter = Exporter()

    @Published var lastRunStatus: String = "未运行"
    @Published var isRunning = false
    @Published var progressCurrent: Int = 0
    @Published var progressTotal: Int = 0

    var fallbackFolderURL: URL { exporter.fallbackFolderURL }

    func export(preset: DateRangePreset, folder: URL?) async {
        let (start, end) = preset.range()
        await exportRange(from: start, to: end, folder: folder, label: preset.title)
    }

    func exportRange(from start: Date, to end: Date, folder: URL?, label: String? = nil) async {
        isRunning = true
        progressCurrent = 0
        progressTotal = 0
        defer { isRunning = false }

        let targetFolder = folder ?? exporter.fallbackFolderURL
        let days = DateRangeUtil.days(from: start, to: end)
        progressTotal = days.count

        do {
            try await healthStore.requestAuthorization()
            let clock = Date()
            var writtenCount = 0
            for day in days {
                let snap = try await healthStore.snapshot(for: day)
                _ = try exporter.write(snap, to: targetFolder)
                writtenCount += 1
                progressCurrent = writtenCount
            }
            let elapsed = Date().timeIntervalSince(clock)
            let desc = label ?? "\(days.count) 天"
            lastRunStatus = String(format: "✓ %@ · %d 文件 · %.1fs", desc, writtenCount, elapsed)
        } catch {
            lastRunStatus = "✗ 失败：\(error.localizedDescription)"
        }
    }
}
