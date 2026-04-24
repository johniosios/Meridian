import AppIntents
import Foundation

@available(iOS 16.0, *)
enum DateRangePresetIntent: String, AppEnum {
    case today, yesterday, last7, last30, thisMonth, lastMonth

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "日期范围" }
    static var caseDisplayRepresentations: [DateRangePresetIntent: DisplayRepresentation] = [
        .today:      "今天",
        .yesterday:  "昨天",
        .last7:      "近 7 天",
        .last30:     "近 30 天",
        .thisMonth:  "本月",
        .lastMonth:  "上月"
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
    static var title: LocalizedStringResource = "导出健康数据"
    static var description = IntentDescription("导出指定日期范围的健康数据为 JSON 文件到已配置的目录。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "日期范围", default: .today)
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
        return .result(dialog: "已导出 \(written) 个文件（\(range.preset.title)）")
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
