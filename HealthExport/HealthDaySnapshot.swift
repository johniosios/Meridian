import Foundation

struct HealthDaySnapshot: Codable {
    let date: String
    let timezone: String
    let exportedAt: String
    let sleep: Sleep?
    let heart: Heart?
    let activity: Activity?
    let body: Body?
    let respiratory: Respiratory?
    let audio: Audio?
    let mindful: Mindful?
    let daylight: Daylight?
    let workouts: [Workout]

    struct Sleep: Codable {
        let inBedMinutes: Int
        let asleepMinutes: Int
        let asleepDeepMinutes: Int?
        let asleepCoreMinutes: Int?
        let asleepRemMinutes: Int?
        let awakeMinutes: Int?
    }

    struct Heart: Codable {
        let restingBpm: Int?
        let maxBpm: Int?
        let minBpm: Int?
        let avgBpm: Int?
        let hrvSdnnMs: Double?
        let walkingAvgBpm: Int?
        let samplesCount: Int
    }

    struct Activity: Codable {
        let steps: Int?
        let distanceKm: Double?
        let activeEnergyKcal: Double?
        let basalEnergyKcal: Double?
        let exerciseMinutes: Int?
        let standHours: Int?
        let flightsClimbed: Int?
    }

    struct Body: Codable {
        let weightKg: Double?
        let bodyFatPct: Double?
        let wristTempC: Double?
    }

    struct Respiratory: Codable {
        let bloodOxygenPctAvg: Double?
        let bloodOxygenSamplesCount: Int
        let respiratoryRateAvg: Double?
        let vo2Max: Double?
    }

    struct Audio: Codable {
        let envSoundAvgDb: Double?
        let envSoundMaxDb: Double?
        let headphoneAvgDb: Double?
    }

    struct Mindful: Codable {
        let minutes: Int
        let sessionsCount: Int
    }

    struct Daylight: Codable {
        let minutes: Int
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
