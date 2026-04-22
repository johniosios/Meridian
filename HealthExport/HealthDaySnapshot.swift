import Foundation

struct HealthDaySnapshot: Codable {
    let date: String
    let timezone: String
    let exportedAt: String
    let sleep: Sleep?
    let heart: Heart?
    let activity: Activity?
    let body: Body?
    let workouts: [Workout]

    struct Sleep: Codable {
        let inBedMinutes: Int
        let asleepMinutes: Int
    }

    struct Heart: Codable {
        let restingBpm: Int?
        let maxBpm: Int?
        let avgBpm: Int?
        let hrvSdnnMs: Double?
        let samplesCount: Int
    }

    struct Activity: Codable {
        let steps: Int?
        let distanceKm: Double?
        let activeEnergyKcal: Double?
        let exerciseMinutes: Int?
        let standHours: Int?
    }

    struct Body: Codable {
        let weightKg: Double?
        let bodyFatPct: Double?
    }

    struct Workout: Codable {
        let type: String
        let start: String
        let end: String
        let durationMinutes: Int
        let distanceKm: Double?
        let activeEnergyKcal: Double?
        let avgBpm: Int?
    }
}

extension JSONEncoder {
    static var healthExportEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
