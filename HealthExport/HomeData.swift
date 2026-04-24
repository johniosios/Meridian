import Foundation
import Combine
import SwiftUI

struct HealthAlert: Identifiable {
    enum Severity {
        case good, warn, bad
        var color: Color {
            switch self {
            case .good: return .green
            case .warn: return .orange
            case .bad:  return .red
            }
        }
    }
    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
}

struct TodayMetrics {
    let sleepHours: Double?
    let sleepAvg: Double?
    let restingHR: Int?
    let restingHRAvg: Double?
    let steps: Int?
    let stepsAvg: Double?
    let hrv: Double?
    let hrvAvg: Double?

    static let empty = TodayMetrics(
        sleepHours: nil, sleepAvg: nil,
        restingHR: nil, restingHRAvg: nil,
        steps: nil, stepsAvg: nil,
        hrv: nil, hrvAvg: nil
    )
}

@MainActor
final class HomeDataLoader: ObservableObject {
    private let healthStore = HealthStore()

    @Published var alerts: [HealthAlert] = []
    @Published var metrics: TodayMetrics = .empty
    @Published var sleepTrend: [ChartPoint] = []
    @Published var hrvTrend: [ChartPoint] = []
    @Published var isLoading = false
    @Published var loadError: String?

    private(set) var windowDays: Int = 7

    func load(days: Int = 7) async {
        windowDays = days
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            try await healthStore.requestAuthorization()
        } catch {
            loadError = error.localizedDescription
            return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        var snapshots: [(Date, HealthDaySnapshot)] = []
        for i in (0..<days).reversed() {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            guard let snap = try? await healthStore.snapshot(for: day) else { continue }
            snapshots.append((day, snap))
        }
        guard let (_, last) = snapshots.last else {
            metrics = .empty; alerts = []; sleepTrend = []; hrvTrend = []; return
        }

        let sleepArr = snapshots.compactMap { $0.1.sleep.asleepMinutes }.map { Double($0) / 60 }
        let restingArr = snapshots.compactMap { $0.1.heart.restingBpm }.map(Double.init)
        let hrvArr = snapshots.compactMap { $0.1.heart.hrvSdnnMs }
        let stepsArr = snapshots.compactMap { $0.1.activity.steps }.map(Double.init)

        metrics = TodayMetrics(
            sleepHours: last.sleep.asleepMinutes.map { Double($0) / 60 },
            sleepAvg: sleepArr.avg,
            restingHR: last.heart.restingBpm,
            restingHRAvg: restingArr.avg,
            steps: last.activity.steps,
            stepsAvg: stepsArr.avg,
            hrv: last.heart.hrvSdnnMs,
            hrvAvg: hrvArr.avg
        )

        alerts = computeAlerts(snapshots: snapshots, metrics: metrics, sleepArr: sleepArr, days: days)

        sleepTrend = snapshots.compactMap { (day, snap) in
            guard let m = snap.sleep.asleepMinutes else { return nil }
            return ChartPoint(date: day, value: Double(m) / 60)
        }
        hrvTrend = snapshots.compactMap { (day, snap) in
            guard let m = snap.heart.hrvSdnnMs else { return nil }
            return ChartPoint(date: day, value: m)
        }
    }

    private func computeAlerts(
        snapshots: [(Date, HealthDaySnapshot)],
        metrics: TodayMetrics,
        sleepArr: [Double],
        days: Int
    ) -> [HealthAlert] {
        var result: [HealthAlert] = []

        // Sleep: 连续 3 天 < 6.5h（固定 3 天窗口，急性信号）
        let recent3 = Array(sleepArr.suffix(3))
        if recent3.count == 3, recent3.allSatisfy({ $0 < 6.5 }) {
            let avg3 = recent3.reduce(0, +) / 3
            result.append(.init(
                severity: .warn,
                title: "连续 3 天睡眠不足 6.5 小时",
                detail: String(format: "近 3 天均值 %.1fh，建议今晚早睡、减少咖啡因", avg3)
            ))
        }

        // Resting HR: today vs window avg
        if let today = metrics.restingHR, let avg = metrics.restingHRAvg {
            let diff = Double(today) - avg
            if diff > 5 {
                result.append(.init(
                    severity: .bad,
                    title: "静息心率偏高 +\(Int(diff))bpm",
                    detail: "vs 近 \(days) 日均 \(Int(avg))bpm，可能疲劳或压力上升"
                ))
            } else if diff < -5 {
                result.append(.init(
                    severity: .good,
                    title: "静息心率改善 \(Int(diff))bpm",
                    detail: "vs 近 \(days) 日均 \(Int(avg))bpm，恢复良好"
                ))
            }
        }

        // HRV: today vs window avg
        if let today = metrics.hrv, let avg = metrics.hrvAvg {
            let diff = today - avg
            if diff < -5 {
                result.append(.init(
                    severity: .warn,
                    title: String(format: "HRV 下降 %.0fms", abs(diff)),
                    detail: "vs 近 \(days) 日均 \(Int(avg))ms，建议训练减量"
                ))
            } else if diff > 5 {
                result.append(.init(
                    severity: .good,
                    title: String(format: "HRV 改善 +%.0fms", diff),
                    detail: "vs 近 \(days) 日均 \(Int(avg))ms，状态良好"
                ))
            }
        }

        // Steps today 显著低于窗口均值
        if let today = metrics.steps, let avg = metrics.stepsAvg,
           Double(today) < 3000, avg > 6000 {
            result.append(.init(
                severity: .warn,
                title: "今日活动偏少",
                detail: "\(today) 步 vs \(days)日均 \(Int(avg)) 步"
            ))
        }

        return result
    }
}

private extension Array where Element == Double {
    var avg: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}
