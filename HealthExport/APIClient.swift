import Foundation

final class APIClient {

    enum APIError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case invalidResponse
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:   return "未配置 API Key（去设置 → AI 分析填写）"
            case .invalidURL:      return "Base URL 无效"
            case .invalidResponse: return "API 响应格式错误"
            case .apiError(let m): return m
            }
        }
    }

    let config: APIConfig
    init(config: APIConfig) { self.config = config }

    func chat(system: String, user: String, maxTokens: Int = 2048) async throws -> String {
        guard !config.apiKey.isEmpty else { throw APIError.missingAPIKey }
        switch config.provider {
        case .anthropic:
            return try await anthropicChat(system: system, user: user, maxTokens: maxTokens)
        case .openai, .custom:
            return try await openAIChat(system: system, user: user, maxTokens: maxTokens)
        }
    }

    // MARK: - Anthropic

    private func anthropicChat(system: String, user: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/v1/messages") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode != 200 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.apiError("HTTP \(http.statusCode): \(text)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw APIError.invalidResponse
        }
        return text
    }

    // MARK: - OpenAI / Compatible

    private func openAIChat(system: String, user: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/v1/chat/completions") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode != 200 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.apiError("HTTP \(http.statusCode): \(text)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw APIError.invalidResponse
        }
        return content
    }
}
