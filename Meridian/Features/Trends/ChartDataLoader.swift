import SwiftUI
import Combine

@MainActor
final class ChartDataLoader: ObservableObject {

    @Published var sleepHours: [ChartPoint] = []
    @Published var steps: [ChartPoint] = []
    @Published var hrv: [ChartPoint] = []
    @Published var restingHR: [ChartPoint] = []
    @Published var activeKcal: [ChartPoint] = []
    @Published var weight: [ChartPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var daysWithData = 0
    @Published var window: ChartWindow = .days7

    func load(healthStore: HealthStore, window: ChartWindow) async {
        self.window = window
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snapshots = try await healthStore.snapshots(lastDays: window.dayCount)
            daysWithData = snapshots.count

            var sleepArr: [ChartPoint] = []
            var stepsArr: [ChartPoint] = []
            var hrvArr: [ChartPoint] = []
            var restingArr: [ChartPoint] = []
            var kcalArr: [ChartPoint] = []
            var weightArr: [ChartPoint] = []

            for item in snapshots {
                let snap = item.snapshot
                let day = item.date
                if let s = snap.sleep.asleepMinutes {
                    sleepArr.append(ChartPoint(date: day, value: Double(s) / 60.0))
                }
                if let s = snap.activity.steps {
                    stepsArr.append(ChartPoint(date: day, value: Double(s)))
                }
                if let h = snap.heart.hrvSdnnMs {
                    hrvArr.append(ChartPoint(date: day, value: h))
                }
                if let r = snap.heart.restingBpm {
                    restingArr.append(ChartPoint(date: day, value: Double(r)))
                }
                if let k = snap.activity.activeEnergyKcal {
                    kcalArr.append(ChartPoint(date: day, value: k))
                }
                if let w = snap.body.weightKg {
                    weightArr.append(ChartPoint(date: day, value: w))
                }
            }

            sleepHours = sleepArr
            steps = stepsArr
            hrv = hrvArr
            restingHR = restingArr
            activeKcal = kcalArr
            weight = weightArr
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
