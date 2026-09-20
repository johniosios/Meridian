import SwiftUI

struct ChartsView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var period: AnalysisPeriod
    @StateObject private var loader = ChartDataLoader()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $period.charts) {
                            ForEach(ChartWindow.allCases) { window in
                                Text(window.pickerTitle).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)

                        coverageCaption
                    }
                    .padding(.horizontal)

                    if loader.isLoading {
                        ProgressView("Loading").padding()
                    }
                    if let err = loader.errorMessage {
                        Text("✗ " + err).font(.caption).foregroundStyle(.red)
                    }

                    ChartCard(title: "Sleep Duration", unit: "hours", points: loader.sleepHours, color: .indigo, domain: period.charts.dateInterval)
                    ChartCard(title: "Steps", unit: "steps", points: loader.steps, color: .green, domain: period.charts.dateInterval)
                    ChartCard(title: "HRV (SDNN)", unit: "ms", points: loader.hrv, color: .orange, domain: period.charts.dateInterval)
                    ChartCard(title: "Resting Heart Rate", unit: "bpm", points: loader.restingHR, color: .red, domain: period.charts.dateInterval)
                    ChartCard(title: "Active Energy", unit: "kcal", points: loader.activeKcal, color: .pink, domain: period.charts.dateInterval)
                    ChartCard(title: "Weight", unit: "kg", points: loader.weight, color: .teal, domain: period.charts.dateInterval)
                }
                .padding(.vertical)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loader.load(healthStore: healthStore, window: period.charts) }
            .onChange(of: period.charts) { _, new in
                Task { await loader.load(healthStore: healthStore, window: new) }
            }
        }
    }

    @ViewBuilder
    private var coverageCaption: some View {
        if loader.isLoading {
            Text("Loading \(period.charts.dayCount) days…")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if loader.daysWithData < period.charts.dayCount {
            Text("Showing \(loader.daysWithData) of \(period.charts.dayCount) days with HealthKit data. Empty days stay blank on the timeline.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("Each chart spans the full \(period.charts.dayCount)-day window.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ChartCard: View {
    let title: String
    let unit: String
    let points: [ChartPoint]
    let color: Color
    var domain: ClosedRange<Date>

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
                    Text("avg \(formatValue(a)) \(unit)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if points.isEmpty {
                Text("No data")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 140)
            } else {
                TrendChart(
                    points: points,
                    color: color,
                    height: 160,
                    domain: domain,
                    showXAxis: true,
                    showYAxis: true,
                    pointSize: 30
                )
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func formatValue(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.0f", v) }
        if v == v.rounded() { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }
}
