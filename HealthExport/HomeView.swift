import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var apiConfig: APIConfig
    @StateObject private var insightGen = InsightGenerator()
    @State private var selectedDays: Int = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    insightCard
                    rangePicker
                    if !apiConfig.isConfigured {
                        configReminder
                    }
                }
                .padding()
            }
            .navigationTitle("今日")
            .refreshable {
                if apiConfig.isConfigured {
                    await insightGen.generate(with: apiConfig, days: selectedDays)
                }
            }
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 健康洞察", systemImage: "sparkles")
                    .font(.caption).bold()
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Button {
                    Task { await insightGen.generate(with: apiConfig, days: selectedDays) }
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
            } else {
                Text(insightGen.insight)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if let date = insightGen.generatedAt, let s = insightGen.lastSummary {
                HStack {
                    Text(s)
                    Spacer()
                    Text("生成于 \(date.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 4)
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
            Text("分析窗口")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Picker("", selection: $selectedDays) {
                Text("7 天").tag(7)
                Text("14 天").tag(14)
                Text("30 天").tag(30)
            }
            .pickerStyle(.segmented)
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
}
