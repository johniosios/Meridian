import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject private var apiConfig: APIConfig
    @EnvironmentObject private var notif: NotificationManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var insightGen = InsightGenerator()
    @StateObject private var home = HomeDataLoader()
    @State private var windowDays: Int = 7

    /// 冷却时间：两次自动生成至少间隔多久（防快速切前后台烧 token）
    private let autoRegenCooldown: TimeInterval = 30 * 60

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
            .navigationTitle("今日")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await home.load(days: windowDays) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(home.isLoading)
                }
            }
            .task {
                await loadAndAutoGenerate()
            }
            .onChange(of: windowDays) { _, new in
                Task { await home.load(days: new) }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await loadAndAutoGenerate() }
                }
            }
            .refreshable {
                await home.load(days: windowDays)
                if apiConfig.isConfigured {
                    await insightGen.generate(with: apiConfig, days: windowDays)
                    pushLatestInsightToNotif()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .dailyNotificationTapped)) { _ in
                Task {
                    await home.load(days: windowDays)
                    if apiConfig.isConfigured {
                        await insightGen.generate(with: apiConfig, days: windowDays)
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
                Label("AI 健康洞察", systemImage: "sparkles")
                    .font(.caption).bold()
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    Task { await insightGen.generate(with: apiConfig, days: windowDays) }
                } label: {
                    HStack(spacing: 4) {
                        if insightGen.isGenerating {
                            ProgressView().controlSize(.small).tint(.white)
                            Text("生成中")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text(insightGen.generatedAt == nil ? "生成洞察" : "重新生成")
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
                    Text("生成于 " + date.formatted(date: .omitted, time: .shortened))
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
                Text("时间窗口")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if home.isLoading {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini)
                        Text("加载中").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Picker("", selection: $windowDays) {
                Text("7 天").tag(7)
                Text("14 天").tag(14)
                Text("30 天").tag(30)
            }
            .pickerStyle(.segmented)
            Text("影响：提醒基准、指标对比、趋势长度、AI 分析输入。切换后点「重新生成」更新 AI。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var configReminder: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("先配置 AI").font(.subheadline).bold()
                Text("去 设置 → AI 分析 填入 API Key 和模型").font(.caption).foregroundStyle(.secondary)
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
                Text("AI 提醒")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                if insightGen.generatedAt != nil {
                    Text(insightGen.alerts.isEmpty ? "无" : "\(insightGen.alerts.count) 项")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if insightGen.generatedAt == nil {
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color.gray).frame(width: 10, height: 10).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("还没有生成提醒").font(.subheadline).bold()
                        Text("点顶部「生成洞察」，AI 会分析你的数据并返回 1-5 条具体提醒")
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
                        Text("AI 判断各项正常").font(.subheadline).bold()
                        Text("最近数据未触发任何警示")
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
            Text("今日关键指标")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                MetricCard(
                    emoji: "😴",
                    label: "睡眠",
                    value: formatHours(home.metrics.sleepHours),
                    trend: trendText(today: home.metrics.sleepHours, avg: home.metrics.sleepAvg, unit: "h", invert: true),
                    trendColor: trendColor(today: home.metrics.sleepHours, avg: home.metrics.sleepAvg, higherIsBetter: true)
                )
                MetricCard(
                    emoji: "❤️",
                    label: "静息心率",
                    value: home.metrics.restingHR.map { "\($0) bpm" } ?? "—",
                    trend: trendText(today: home.metrics.restingHR.map(Double.init), avg: home.metrics.restingHRAvg, unit: "", invert: false),
                    trendColor: trendColor(today: home.metrics.restingHR.map(Double.init), avg: home.metrics.restingHRAvg, higherIsBetter: false)
                )
                MetricCard(
                    emoji: "🏃",
                    label: "步数",
                    value: home.metrics.steps.map { "\($0)" } ?? "—",
                    trend: home.metrics.stepsAvg.map { "\(windowDays)日均 \(Int($0))" } ?? "无基线",
                    trendColor: .gray
                )
                MetricCard(
                    emoji: "📊",
                    label: "HRV",
                    value: home.metrics.hrv.map { String(format: "%.0f ms", $0) } ?? "—",
                    trend: trendText(today: home.metrics.hrv, avg: home.metrics.hrvAvg, unit: "", invert: false),
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

    private func trendText(today: Double?, avg: Double?, unit: String, invert: Bool) -> String {
        guard let today = today, let avg = avg else { return "无基线" }
        let diff = today - avg
        if abs(diff) < 0.1 { return "与基线一致" }
        let arrow = diff > 0 ? "↑" : "↓"
        return String(format: "%@ %.1f%@ vs %d日均", arrow, abs(diff), unit, windowDays)
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
                Text("近 \(windowDays) 天趋势")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                NavigationLink(destination: ChartsView()) {
                    Text("查看全部 ›").font(.caption).foregroundStyle(Color.accentColor)
                }
            }
            miniTrend(title: "睡眠（小时）", points: home.sleepTrend, color: .indigo)
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
                    Text(String(format: "均 %.1f", avg))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if points.isEmpty {
                Text("无数据").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                Chart(points) { p in
                    LineMark(x: .value("date", p.date), y: .value("value", p.value))
                        .foregroundStyle(color)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("date", p.date), y: .value("value", p.value))
                        .foregroundStyle(color)
                        .symbolSize(16)
                }
                .frame(height: 70)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Auto generate + push updated notif body

    /// Refreshes home metrics on every entry; regenerates AI if configured and cooldown elapsed.
    private func loadAndAutoGenerate() async {
        await home.load(days: windowDays)
        guard apiConfig.isConfigured, shouldAutoRegenerate() else { return }
        await insightGen.generate(with: apiConfig, days: windowDays)
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
