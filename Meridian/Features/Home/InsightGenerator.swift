import Foundation
import Combine

@MainActor
final class InsightGenerator: ObservableObject {

    @Published var insight: String = "Tap Generate Insights to have AI analyze recent data and produce a summary plus alerts."
    @Published var alerts: [HealthAlert] = []
    @Published var isGenerating = false
    @Published var lastError: String?
    @Published var generatedAt: Date?
    @Published var lastSummary: String?
    @Published var generatedFor: TimeWindow?

    func isStale(for window: TimeWindow) -> Bool {
        generatedAt != nil && generatedFor != window
    }

    func generate(healthStore: HealthStore, apiConfig: APIConfig, window: TimeWindow) async {
        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        do {
            let snapshots = try await healthStore.snapshots(lastDays: window.dayCount)

            let encoder = JSONEncoder.healthExportEncoder
            let json = String(data: try encoder.encode(snapshots.map(\.snapshot)), encoding: .utf8) ?? "[]"

            let days = window.dayCount
            let system = """
            You are the user's personal health coach. Analyze the last \(days) days of health data and return **strict JSON** only — no other text (no markdown code fences, no explanation).

            Schema:
            {
              "summary": "Markdown analysis with sections ## Key Takeaways / ## Trends / ## Recommendations, under 300 words total",
              "alerts": [
                { "severity": "good|warn|bad", "title": "< 15 words", "detail": "< 40 words with specifics" }
              ]
            }

            Rules:
            - At most 5 alerts, sorted by importance
            - good = positive signal (improving, excellent); warn = notable deviation; bad = clear anomaly
            - Write summary in concise English; markdown may use **bold** and - lists
            - Skip generic disclaimers like "consult a doctor"; assume a healthy adult user
            - Do not repeat raw numbers from the JSON — interpret them
            """

            let user = "Last \(days) days of data (JSON array in ascending date order):\n\(json)"

            let client = APIClient(config: apiConfig)
            let text = try await client.chat(system: system, user: user, maxTokens: 1500)

            let (summary, parsedAlerts) = Self.parseResponse(text)
            insight = summary
            alerts = parsedAlerts
            generatedAt = Date()
            generatedFor = window
            lastSummary = "Based on last \(days) days · \(apiConfig.model)"
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

        if trimmed.hasPrefix("{") {
            return trimmed
        }

        if let startFence = trimmed.range(of: "```") {
            var after = String(trimmed[startFence.upperBound...])
            if after.hasPrefix("json") { after = String(after.dropFirst(4)) }
            if let endFence = after.range(of: "```") {
                return String(after[..<endFence.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}"),
           firstBrace < lastBrace {
            return String(trimmed[firstBrace...lastBrace])
        }
        return nil
    }
}
