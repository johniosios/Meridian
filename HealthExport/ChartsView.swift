import SwiftUI
import Charts
import Combine

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

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

    func load(healthStore: HealthStore, days: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await healthStore.requestAuthorization()
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())

            var sleepArr: [ChartPoint] = []
            var stepsArr: [ChartPoint] = []
            var hrvArr: [ChartPoint] = []
            var restingArr: [ChartPoint] = []
            var kcalArr: [ChartPoint] = []
            var weightArr: [ChartPoint] = []

            for i in (0..<days).reversed() {
                guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
                guard let snap = try? await healthStore.snapshot(for: day) else { continue }
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

struct ChartsView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @StateObject private var loader = ChartDataLoader()
    @State private var days: Int = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("", selection: $days) {
                        Text("7 天").tag(7)
                        Text("30 天").tag(30)
                        Text("90 天").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if loader.isLoading {
                        ProgressView("加载中").padding()
                    }
                    if let err = loader.errorMessage {
                        Text("✗ " + err).font(.caption).foregroundStyle(.red)
                    }

                    ChartCard(title: "睡眠时长", unit: "小时", points: loader.sleepHours, color: .indigo)
                    ChartCard(title: "步数", unit: "步", points: loader.steps, color: .green)
                    ChartCard(title: "HRV (SDNN)", unit: "ms", points: loader.hrv, color: .orange)
                    ChartCard(title: "静息心率", unit: "bpm", points: loader.restingHR, color: .red)
                    ChartCard(title: "活动能量", unit: "kcal", points: loader.activeKcal, color: .pink)
                    ChartCard(title: "体重", unit: "kg", points: loader.weight, color: .teal)
                }
                .padding(.vertical)
            }
            .navigationTitle("趋势")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loader.load(healthStore: healthStore, days: days) }
                    } label: { Image(systemName: "arrow.clockwise") }
                    .disabled(loader.isLoading)
                }
            }
            .task { await loader.load(healthStore: healthStore, days: days) }
            .onChange(of: days) { _, new in
                Task { await loader.load(healthStore: healthStore, days: new) }
            }
        }
    }
}

struct ChartCard: View {
    let title: String
    let unit: String
    let points: [ChartPoint]
    let color: Color

    private var avg: Double? {
        guard !points.isEmpty else { return nil }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline).bold()
                Spacer()
                if let a = avg {
                    Text("均值 \(formatValue(a)) \(unit)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if points.isEmpty {
                Text("无数据")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 140)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("date", p.date), y: .value("value", p.value))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("date", p.date), y: .value("value", p.value))
                        .foregroundStyle(color)
                        .symbolSize(30)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride))
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var xAxisStride: Calendar.Component {
        points.count <= 14 ? .day : (points.count <= 60 ? .weekOfYear : .month)
    }

    private func formatValue(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.0f", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }
}

