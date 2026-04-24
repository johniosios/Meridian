import Foundation
import Combine

@MainActor
final class APIConfig: ObservableObject {

    enum Provider: String, CaseIterable, Identifiable {
        case anthropic = "Anthropic"
        case openai = "OpenAI"
        case custom = "Custom (OpenAI-compatible)"
        var id: String { rawValue }

        var defaultBaseURL: String {
            switch self {
            case .anthropic: return "https://api.anthropic.com"
            case .openai:    return "https://api.openai.com"
            case .custom:    return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .anthropic: return "claude-opus-4-7"
            case .openai:    return "gpt-4o"
            case .custom:    return ""
            }
        }
    }

    @Published var provider: Provider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: "apiProvider")
            if oldValue != provider {
                baseURL = provider.defaultBaseURL
                model = provider.defaultModel
            }
        }
    }

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "apiBaseURL") }
    }

    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "apiModel") }
    }

    @Published var apiKey: String {
        didSet {
            if apiKey.isEmpty {
                KeychainStore.delete(key: "apiKey")
            } else {
                try? KeychainStore.save(key: "apiKey", value: apiKey)
            }
        }
    }

    var isConfigured: Bool { !apiKey.isEmpty && !model.isEmpty && !baseURL.isEmpty }

    init() {
        let rawProvider = UserDefaults.standard.string(forKey: "apiProvider") ?? Provider.anthropic.rawValue
        let p = Provider(rawValue: rawProvider) ?? .anthropic
        self.provider = p
        self.baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? p.defaultBaseURL
        self.model = UserDefaults.standard.string(forKey: "apiModel") ?? p.defaultModel
        self.apiKey = KeychainStore.load(key: "apiKey") ?? ""
    }
}
