import SwiftUI

struct HealthAlert: Identifiable {
    enum Severity {
        case good, warn, bad
        var color: Color {
            switch self {
            case .good: return .green
            case .warn: return .orange
            case .bad:  return .red
            }
        }
    }
    let id = UUID()
    let severity: Severity
    let title: String
    let detail: String
}
