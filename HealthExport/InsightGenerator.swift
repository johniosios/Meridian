import Foundation
import Combine

@MainActor
final class InsightGenerator: ObservableObject {

    @Published var insight: String = "点「生成洞察」让 AI 分析最近数据，给出摘要 + 提醒。"
    @Published var alerts: [HealthAlert] = []
    @Published var isGenerating = false
    @Published var lastError: String?
    @Published var generatedAt: Date?
    @Published var lastSummary: String?

    func generate(healthStore: HealthStore, apiConfig: APIConfig, days: Int = 7) async {
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
                guard let snap = try? await healthStore.snapshot(for: day) else { continue }
                snapshots.append(snap)
            }

            let encoder = JSONEncoder.healthExportEncoder
            let json = String(data: try encoder.encode(snapshots), encoding: .utf8) ?? "[]"

            let system = """
            你是用户的个人健康教练。分析最近 \(days) 天健康数据，返回**严格的 JSON**，除 JSON 外不要任何文字（不要 markdown 代码围栏、不要解释）。

            Schema:
            {
              "summary": "markdown 格式的分析总结，章节用 ## 今日重点 / ## 趋势观察 / ## 建议，总长 < 300 字",
              "alerts": [
                { "severity": "good|warn|bad", "title": "< 15 字", "detail": "< 40 字具体说明" }
              ]
            }

            规则：
            - alerts 最多 5 条，按重要性排序
            - good = 正面信号（改善、优秀）；warn = 需要注意的偏离；bad = 明显异常
            - summary 用简洁中文，markdown 允许 **加粗** 和 - 列表
            - 不要"请咨询医生"之类的废话，假设用户是健康成年人
            - 不要复述 JSON 里的原始数字，提炼后再讲
            """

            let user = "最近 \(days) 天数据（按日期升序的 JSON 数组）：\n\(json)"

            let client = APIClient(config: apiConfig)
            let text = try await client.chat(system: system, user: user, maxTokens: 1500)

            let (summary, parsedAlerts) = Self.parseResponse(text)
            insight = summary
            alerts = parsedAlerts
            generatedAt = Date()
            lastSummary = "基于近 \(days) 天 · \(apiConfig.model)"
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Response parsing

    /// Tries to extract JSON from AI response (handles stray code fences / leading text).
    /// Falls back to treating the whole text as summary if parsing fails.
    static func parseResponse(_ raw: String) -> (summary: String, alerts: [HealthAlert]) {
        guard let jsonString = extractJSON(from: raw),
              let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (raw, [])
        }
        let summary = (obj["summary"] as? String) ?? raw
        let rawAlerts = (obj["alerts"] as? [[String: Any]]) ?? []
        let alerts = rawAlerts.compactMap { dict -> HealthAlert? in
            guard let title = dict["title"] as? String,
                  let detail = dict["detail"] as? String,
                  let sev = dict["severity"] as? String else { return nil }
            let severity: HealthAlert.Severity
            switch sev.lowercased() {
            case "good": severity = .good
            case "bad":  severity = .bad
            default:     severity = .warn
            }
            return HealthAlert(severity: severity, title: title, detail: detail)
        }
        return (summary, alerts)
    }

    private static func extractJSON(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Case A: already starts with {
        if trimmed.hasPrefix("{") {
            return trimmed
        }

        // Case B: wrapped in ```json ... ``` or ``` ... ```
        if let startFence = trimmed.range(of: "```") {
            var after = String(trimmed[startFence.upperBound...])
            if after.hasPrefix("json") { after = String(after.dropFirst(4)) }
            if let endFence = after.range(of: "```") {
                return String(after[..<endFence.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Case C: find first "{" and matching last "}"
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}"),
           firstBrace < lastBrace {
            return String(trimmed[firstBrace...lastBrace])
        }
        return nil
    }
}
