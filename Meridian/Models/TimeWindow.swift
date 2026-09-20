import Foundation
import Combine

/// Lookback used on Today (metrics, mini-trends, AI input).
enum TimeWindow: Int, CaseIterable, Identifiable, Hashable {
    case days7 = 7
    case days14 = 14
    case days30 = 30

    var id: Int { rawValue }
    var dayCount: Int { rawValue }
    var pickerTitle: String { "\(rawValue) days" }

    /// Inclusive start-of-day range ending today.
    var dateInterval: ClosedRange<Date> {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(dayCount - 1), to: end)!
        return start...end
    }
}

/// Lookback used on the Trends tab (longer ranges for charts only).
enum ChartWindow: Int, CaseIterable, Identifiable, Hashable {
    case days7 = 7
    case days30 = 30
    case days90 = 90

    var id: Int { rawValue }
    var dayCount: Int { rawValue }
    var pickerTitle: String { "\(rawValue) days" }

    var dateInterval: ClosedRange<Date> {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -(dayCount - 1), to: end)!
        return start...end
    }
}

/// Shared, persisted period selection for Today and Trends.
@MainActor
final class AnalysisPeriod: ObservableObject {
    @Published var home: TimeWindow {
        didSet { UserDefaults.standard.set(home.rawValue, forKey: Self.homeKey) }
    }
    @Published var charts: ChartWindow {
        didSet { UserDefaults.standard.set(charts.rawValue, forKey: Self.chartsKey) }
    }

    private static let homeKey = "analysisTimeWindow"
    private static let chartsKey = "chartTimeWindow"

    init() {
        let savedHome = UserDefaults.standard.integer(forKey: Self.homeKey)
        home = TimeWindow(rawValue: savedHome) ?? .days7
        let savedCharts = UserDefaults.standard.integer(forKey: Self.chartsKey)
        charts = ChartWindow(rawValue: savedCharts) ?? .days7
    }
}
