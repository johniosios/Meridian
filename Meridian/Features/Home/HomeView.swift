import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var healthStore: HealthStore
    @EnvironmentObject private var apiConfig: APIConfig
    @EnvironmentObject private var notif: NotificationManager
    @EnvironmentObject private var period: AnalysisPeriod
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var insightGen = InsightGenerator()
    @StateObject private var home = HomeDataLoader()

    /// Minimum interval between auto-regenerations (avoids burning tokens on rapid foreground/background switches).
    private let autoRegenCooldown: TimeInterval = 30 * 60

    private var window: TimeWindow { period.home }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    insightCard
                    rangePicker
                    if !apiConfig.isConfigured {
                        configReminder
                    }
                    alertsSection
                    metricsSection
                    miniTrendsSection
                }
                .padding()
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadAndAutoGenerate()
            }
            .onChange(of: period.home) { _, new in
                Task { await home.load(healthStore: healthStore, window: new) }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await loadAndAutoGenerate() }
                }
            }
            .refreshable {
                await home.load(healthStore: healthStore, window: window)
                if apiConfig.isConfigured {
                    await insightGen.generate(healthStore: healthStore, apiConfig: apiConfig, window: window)
                    pushLatestInsightToNotif()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dailyNotificationTapped)) { _ in
                Task {
                    await home.load(healthStore: healthStore, window: window)
                    if apiConfig.isConfigured {
                        await insightGen.generate(healthStore: healthStore, apiConfig: apiConfig, window: window)
                        pushLatestInsightToNotif()
                    }
                }
            }
        }
    }

    // MARK: - AI Insight

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Health Insights", systemImage: "sparkles")
                    .font(.caption).bold()
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    Task { await insightGen.generate(healthStore: healthStore, apiConfig: apiConfig, window: window) }
                } label: {
                    HStack(spacing: 4) {
                        if insightGen.isGenerating {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("Generating")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text(insightGen.generatedAt == nil ? "Generate Insights" : "Regenerate")
                        }
                    }
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.22))
                    .clipShape(Capsule())
                }
                .disabled(insightGen.isGenerating || !apiConfig.isConfigured)
            }

            if insightGen.isStale(for: window) {
                Text("Insights still use the previous window. Tap Regenerate to analyze the last \(window.dayCount) days.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let err = insightGen.lastError {
                Text("✗ " + err)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            } else if insightGen.generatedAt == nil {
                Text(insightGen.insight)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                MarkdownText(text: insightGen.insight)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
            }

            if let date = insightGen.generatedAt, let s = insightGen.lastSummary {
                HStack {
                    Text(s)
                    Spacer()
                    Text("Generated at " + date.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 6)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.56, green: 0.37, blue: 0.91),
                         Color(red: 0.29, green: 0.56, blue: 0.94)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.blue.opacity(0.15), radius: 8, y: 4)
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Time Window")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if home.isLoading {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("Loading").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Picker("", selection: $period.home) {
                ForEach(TimeWindow.allCases) { w in
                    Text(w.pickerTitle).tag(w)
                }
            }
            .pickerStyle(.segmented)

            Text("Today’s numbers stay the same. This window is the average, trend timeline, and AI lookback.")
                .font(.caption2).foregroundStyle(.secondary)

            if !home.isLoading, home.daysWithData > 0, home.daysWithData < window.dayCount {
                Text("HealthKit has data on \(home.daysWithData) of \(window.dayCount) days, so averages may barely move.")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private var configReminder: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Configure AI First").font(.subheadline).bold()
                Text("Go to Settings → AI Analysis and enter your API key and model").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Alerts")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if insightGen.generatedAt != nil {
                    Text(insightGen.alerts.isEmpty ? "None" : "\(insightGen.alerts.count) items")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if insightGen.generatedAt == nil {
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.gray).frame(width: 10, height: 10).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No alerts yet").font(.subheadline).bold()
                        Text("Tap Generate Insights at the top — AI will analyze your data and return 1–5 specific alerts")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if insightGen.alerts.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.green).frame(width: 10, height: 10).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All clear according to AI").font(.subheadline).bold()
                        Text("Recent data did not trigger any alerts")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(insightGen.alerts) { alert in
                    alertRow(alert)
                }
            }
        }
    }

    private func alertRow(_ alert: HealthAlert) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(alert.severity.color)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title).font(.subheadline).bold()
                Text(alert.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Key Metrics")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                MetricCard(
                    emoji: "😴",
                    label: "Sleep",
                    value: formatHours(home.metrics.sleepHours),
                    trend: trendText(today: home.metrics.sleepHours, avg: home.metrics.sleepAvg, unit: "h"),
                    trendColor: trendColor(today: home.metrics.sleepHours, avg: home.metrics.sleepAvg, higherIsBetter: true)
                )
                MetricCard(
                    emoji: "❤️",
                    label: "Resting HR",
                    value: home.metrics.restingHR.map { "\($0) bpm" } ?? "—",
                    trend: trendText(today: home.metrics.restingHR.map(Double.init), avg: home.metrics.restingHRAvg, unit: ""),
                    trendColor: trendColor(today: home.metrics.restingHR.map(Double.init), avg: home.metrics.restingHRAvg, higherIsBetter: false)
                )
                MetricCard(
                    emoji: "🏃",
                    label: "Steps",
                    value: home.metrics.steps.map { "\($0)" } ?? "—",
                    trend: home.metrics.stepsAvg.map { "\(window.dayCount)-day avg \(Int($0))" } ?? "No baseline",
                    trendColor: .gray
                )
                MetricCard(
                    emoji: "📊",
                    label: "HRV",
                    value: home.metrics.hrv.map { String(format: "%.0f ms", $0) } ?? "—",
                    trend: trendText(today: home.metrics.hrv, avg: home.metrics.hrvAvg, unit: ""),
                    trendColor: trendColor(today: home.metrics.hrv, avg: home.metrics.hrvAvg, higherIsBetter: true)
                )
            }
        }
    }

    private func formatHours(_ h: Double?) -> String {
        guard let h = h else { return "—" }
        let hr = Int(h)
        let m = Int((h - Double(hr)) * 60)
        return "\(hr)h \(m)m"
    }

    private func trendText(today: Double?, avg: Double?, unit: String) -> String {
        guard let today = today, let avg = avg else { return "No baseline" }
        let diff = today - avg
        if abs(diff) < 0.1 { return "Matches \(window.dayCount)-day avg" }
        let arrow = diff > 0 ? "↑" : "↓"
        return String(format: "%@ %.1f%@ vs %d-day avg", arrow, abs(diff), unit, window.dayCount)
    }

    private func trendColor(today: Double?, avg: Double?, higherIsBetter: Bool) -> Color {
        guard let today = today, let avg = avg else { return .gray }
        let diff = today - avg
        if abs(diff) < 0.1 { return .gray }
        let isUp = diff > 0
        let isGood = higherIsBetter ? isUp : !isUp
        return isGood ? .green : .red
    }

    // MARK: - Mini trends

    private var miniTrendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last \(window.dayCount) Days Trend")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                NavigationLink(destination: ChartsView()) {
                    Text("View All ›").font(.caption).foregroundStyle(Color.accentColor)
                }
            }
            miniTrend(title: "Sleep (hours)", points: home.sleepTrend, color: .indigo)
            miniTrend(title: "HRV (ms)", points: home.hrvTrend, color: .orange)
        }
    }

    private func miniTrend(title: String, points: [ChartPoint], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.footnote).bold()
                Spacer()
                if !points.isEmpty {
                    let avg = points.map(\.value).reduce(0, +) / Double(points.count)
                    Text(String(format: "avg %.1f", avg))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if points.isEmpty {
                Text("No data").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                TrendChart(
                    points: points,
                    color: color,
                    height: 70,
                    domain: window.dateInterval,
                    showXAxis: true,
                    pointSize: 16
                )
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Auto generate + push updated notif body

    /// Refreshes home metrics on every entry; regenerates AI if configured and cooldown elapsed.
    private func loadAndAutoGenerate() async {
        await home.load(healthStore: healthStore, window: window)
        guard apiConfig.isConfigured, shouldAutoRegenerate() else { return }
        await insightGen.generate(healthStore: healthStore, apiConfig: apiConfig, window: window)
        pushLatestInsightToNotif()
    }

    /// True if never generated, or last gen was longer than cooldown ago.
    private func shouldAutoRegenerate() -> Bool {
        guard let last = insightGen.generatedAt else { return true }
        return Date().timeIntervalSince(last) > autoRegenCooldown
    }

    /// Updates the daily notification body with the latest AI summary.
    private func pushLatestInsightToNotif() {
        guard notif.dailyEnabled, let summary = summaryForNotif() else { return }
        notif.updateDailyBody(summary)
    }

    /// First non-heading paragraph from the markdown, capped at 140 chars.
    private func summaryForNotif() -> String? {
        guard insightGen.generatedAt != nil else { return nil }
        let text = insightGen.insight
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("-") && !$0.hasPrefix("*") }
        let first = paragraphs.first ?? text
        return String(first.prefix(140))
    }
}

private struct MetricCard: View {
    let emoji: String
    let label: String
    let value: String
    let trend: String
    let trendColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3).bold()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(trend)
                .font(.caption2)
                .foregroundStyle(trendColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
