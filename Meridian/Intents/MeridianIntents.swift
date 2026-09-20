import AppIntents
import Foundation

@available(iOS 16.0, *)
enum DateRangePresetIntent: String, AppEnum {
    case today, yesterday, last7, last30, thisMonth, lastMonth

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Date Range" }
    static var caseDisplayRepresentations: [DateRangePresetIntent: DisplayRepresentation] = [
        .today:      "Today",
        .yesterday:  "Yesterday",
        .last7:      "Last 7 Days",
        .last30:     "Last 30 Days",
        .thisMonth:  "This Month",
        .lastMonth:  "Last Month"
    ]

    fileprivate var preset: DateRangePreset {
        switch self {
        case .today:      return .today
        case .yesterday:  return .yesterday
        case .last7:      return .last7
        case .last30:     return .last30
        case .thisMonth:  return .thisMonth
        case .lastMonth:  return .lastMonth
        }
    }
}

@available(iOS 16.0, *)
struct ExportHealthDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Health Data"
    static var description = IntentDescription("Export health data for the selected date range as JSON files to the configured folder.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Date Range", default: .today)
    var range: DateRangePresetIntent

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let health = HealthStore()
        try await health.requestAuthorization()

        let exporter = Exporter()
        let folder = FolderResolver.resolve() ?? exporter.fallbackFolderURL

        let (start, end) = range.preset.range()
        let days = DateRangeUtil.days(from: start, to: end)

        var written = 0
        for day in days {
            let snap = try await health.snapshot(for: day)
            _ = try exporter.write(snap, to: folder)
            written += 1
        }
        return .result(dialog: "Exported \(written) files (\(range.preset.title))")
    }
}

enum FolderResolver {
    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: "exportFolderBookmark") else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        return url.startAccessingSecurityScopedResource() ? url : nil
    }
}
