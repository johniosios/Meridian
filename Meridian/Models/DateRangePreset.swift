import Foundation

enum DateRangePreset: String, CaseIterable, Identifiable {
    case today
    case yesterday
    case last7
    case last30
    case thisMonth
    case lastMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .last7: return "Last 7 Days"
        case .last30: return "Last 30 Days"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        }
    }

    func range(now: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        switch self {
        case .today:
            return (today, today)
        case .yesterday:
            let y = cal.date(byAdding: .day, value: -1, to: today)!
            return (y, y)
        case .last7:
            let start = cal.date(byAdding: .day, value: -6, to: today)!
            return (start, today)
        case .last30:
            let start = cal.date(byAdding: .day, value: -29, to: today)!
            return (start, today)
        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            return (start, today)
        case .lastMonth:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
            let lastStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let lastEnd = cal.date(byAdding: .day, value: -1, to: thisMonthStart)!
            return (lastStart, lastEnd)
        }
    }
}

enum DateRangeUtil {
    static func days(from start: Date, to end: Date) -> [Date] {
        let cal = Calendar.current
        var result: [Date] = []
        var current = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while current <= endDay {
            result.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }
}
