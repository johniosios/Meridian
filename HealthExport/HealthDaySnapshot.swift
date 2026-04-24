import Foundation

struct HealthDaySnapshot: Encodable {
    let date: String
    let timezone: String
    let exportedAt: String
    let sleep: Sleep
    let heart: Heart
    let activity: Activity
    let body: Body
    let respiratory: Respiratory
    let audio: Audio
    let mindful: Mindful
    let daylight: Daylight
    let workouts: [Workout]

    struct Sleep: Encodable {
        let inBedMinutes: Int?
        let asleepMinutes: Int?
        let asleepDeepMinutes: Int?
        let asleepCoreMinutes: Int?
        let asleepRemMinutes: Int?
        let awakeMinutes: Int?
    }

    struct Heart: Encodable {
        let restingBpm: Int?
        let maxBpm: Int?
        let minBpm: Int?
        let avgBpm: Int?
        let hrvSdnnMs: Double?
        let walkingAvgBpm: Int?
        let samplesCount: Int?
    }

    struct Activity: Encodable {
        let steps: Int?
        let distanceKm: Double?
        let activeEnergyKcal: Double?
        let basalEnergyKcal: Double?
        let exerciseMinutes: Int?
        let standHours: Int?
        let flightsClimbed: Int?
    }

    struct Body: Encodable {
        let weightKg: Double?
        let bodyFatPct: Double?
        let wristTempC: Double?
    }

    struct Respiratory: Encodable {
        let bloodOxygenPctAvg: Double?
        let bloodOxygenSamplesCount: Int?
        let respiratoryRateAvg: Double?
        let vo2Max: Double?
    }

    struct Audio: Encodable {
        let envSoundAvgDb: Double?
        let envSoundMaxDb: Double?
        let headphoneAvgDb: Double?
    }

    struct Mindful: Encodable {
        let minutes: Int?
        let sessionsCount: Int?
    }

    struct Daylight: Encodable {
        let minutes: Int?
    }

    struct Workout: Encodable {
        let type: String
        let start: String
        let end: String
        let durationMinutes: Int
        let distanceKm: Double?
        let activeEnergyKcal: Double?
        let avgBpm: Int?
    }
}

// MARK: - Manual encode to always emit all keys (nil -> null)

extension HealthDaySnapshot {
    enum CodingKeys: String, CodingKey {
        case date, timezone, exportedAt, sleep, heart, activity, body, respiratory, audio, mindful, daylight, workouts
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(timezone, forKey: .timezone)
        try c.encode(exportedAt, forKey: .exportedAt)
        try c.encode(sleep, forKey: .sleep)
        try c.encode(heart, forKey: .heart)
        try c.encode(activity, forKey: .activity)
        try c.encode(body, forKey: .body)
        try c.encode(respiratory, forKey: .respiratory)
        try c.encode(audio, forKey: .audio)
        try c.encode(mindful, forKey: .mindful)
        try c.encode(daylight, forKey: .daylight)
        try c.encode(workouts, forKey: .workouts)
    }
}

extension HealthDaySnapshot.Sleep {
    enum CodingKeys: String, CodingKey {
        case inBedMinutes, asleepMinutes, asleepDeepMinutes, asleepCoreMinutes, asleepRemMinutes, awakeMinutes
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(inBedMinutes, forKey: .inBedMinutes)
        try c.encode(asleepMinutes, forKey: .asleepMinutes)
        try c.encode(asleepDeepMinutes, forKey: .asleepDeepMinutes)
        try c.encode(asleepCoreMinutes, forKey: .asleepCoreMinutes)
        try c.encode(asleepRemMinutes, forKey: .asleepRemMinutes)
        try c.encode(awakeMinutes, forKey: .awakeMinutes)
    }
}

extension HealthDaySnapshot.Heart {
    enum CodingKeys: String, CodingKey {
        case restingBpm, maxBpm, minBpm, avgBpm, hrvSdnnMs, walkingAvgBpm, samplesCount
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(restingBpm, forKey: .restingBpm)
        try c.encode(maxBpm, forKey: .maxBpm)
        try c.encode(minBpm, forKey: .minBpm)
        try c.encode(avgBpm, forKey: .avgBpm)
        try c.encode(hrvSdnnMs, forKey: .hrvSdnnMs)
        try c.encode(walkingAvgBpm, forKey: .walkingAvgBpm)
        try c.encode(samplesCount, forKey: .samplesCount)
    }
}

extension HealthDaySnapshot.Activity {
    enum CodingKeys: String, CodingKey {
        case steps, distanceKm, activeEnergyKcal, basalEnergyKcal, exerciseMinutes, standHours, flightsClimbed
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(steps, forKey: .steps)
        try c.encode(distanceKm, forKey: .distanceKm)
        try c.encode(activeEnergyKcal, forKey: .activeEnergyKcal)
        try c.encode(basalEnergyKcal, forKey: .basalEnergyKcal)
        try c.encode(exerciseMinutes, forKey: .exerciseMinutes)
        try c.encode(standHours, forKey: .standHours)
        try c.encode(flightsClimbed, forKey: .flightsClimbed)
    }
}

extension HealthDaySnapshot.Body {
    enum CodingKeys: String, CodingKey {
        case weightKg, bodyFatPct, wristTempC
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(weightKg, forKey: .weightKg)
        try c.encode(bodyFatPct, forKey: .bodyFatPct)
        try c.encode(wristTempC, forKey: .wristTempC)
    }
}

extension HealthDaySnapshot.Respiratory {
    enum CodingKeys: String, CodingKey {
        case bloodOxygenPctAvg, bloodOxygenSamplesCount, respiratoryRateAvg, vo2Max
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bloodOxygenPctAvg, forKey: .bloodOxygenPctAvg)
        try c.encode(bloodOxygenSamplesCount, forKey: .bloodOxygenSamplesCount)
        try c.encode(respiratoryRateAvg, forKey: .respiratoryRateAvg)
        try c.encode(vo2Max, forKey: .vo2Max)
    }
}

extension HealthDaySnapshot.Audio {
    enum CodingKeys: String, CodingKey {
        case envSoundAvgDb, envSoundMaxDb, headphoneAvgDb
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(envSoundAvgDb, forKey: .envSoundAvgDb)
        try c.encode(envSoundMaxDb, forKey: .envSoundMaxDb)
        try c.encode(headphoneAvgDb, forKey: .headphoneAvgDb)
    }
}

extension HealthDaySnapshot.Mindful {
    enum CodingKeys: String, CodingKey {
        case minutes, sessionsCount
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(minutes, forKey: .minutes)
        try c.encode(sessionsCount, forKey: .sessionsCount)
    }
}

extension HealthDaySnapshot.Daylight {
    enum CodingKeys: String, CodingKey {
        case minutes
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(minutes, forKey: .minutes)
    }
}

extension HealthDaySnapshot.Workout {
    enum CodingKeys: String, CodingKey {
        case type, start, end, durationMinutes, distanceKm, activeEnergyKcal, avgBpm
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        try c.encode(start, forKey: .start)
        try c.encode(end, forKey: .end)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(distanceKm, forKey: .distanceKm)
        try c.encode(activeEnergyKcal, forKey: .activeEnergyKcal)
        try c.encode(avgBpm, forKey: .avgBpm)
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
