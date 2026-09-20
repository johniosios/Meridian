import Foundation

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
