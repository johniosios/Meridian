import Foundation
import Combine

@MainActor
final class InsightGenerator: ObservableObject {

    private let healthStore = HealthStore()

    @Published var insight: String = "点「生成洞察」让 AI 分析你最近 7 天的健康数据。"
    @Published var isGenerating = false
    @Published var lastError: String?
    @Published var generatedAt: Date?
    @Published var lastSummary: String?   // e.g. "基于 近 7 天 · 7 天"

    func generate(with apiConfig: APIConfig, days: Int = 7) async {
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        do {
            try await healthStore.requestAuthorization()

            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            var snapshots: [HealthDaySnapshot] = []
            for i in (0..<days).reversed() {
                guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
                let snap = try await healthStore.snapshot(for: day)
                snapshots.append(snap)
            }

            let encoder = JSONEncoder.healthExportEncoder
            let json = String(data: try encoder.encode(snapshots), encoding: .utf8) ?? "[]"

            let system = """
            你是用户的个人健康教练。用户会发送最近 N 天的健康数据（JSON 数组，每个元素是一天的汇总）。

            你的任务：
            1. 用简洁中文总结关键信号（3 行以内），指出趋势和异常
            2. 给出 2-3 条**具体、可执行**的行动建议
            3. 输出使用 Markdown，章节：## 今日重点 / ## 趋势观察 / ## 建议
            4. 不要说"请咨询医生"这类套话——假设用户是健康成年人
            5. 不要重复 JSON 里已有的原始数字，提炼后再讲
            """

            let user = "最近 \(days) 天数据（按日期升序）：\n```json\n\(json)\n```"

            let client = APIClient(config: apiConfig)
            let text = try await client.chat(system: system, user: user, maxTokens: 1500)

            insight = text
            generatedAt = Date()
            lastSummary = "基于近 \(days) 天数据 · 模型 \(apiConfig.model)"
        } catch {
            lastError = error.localizedDescription
        }
    }
}
