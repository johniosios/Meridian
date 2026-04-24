import Foundation
import HealthKit

final class HealthStore {
    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard Self.isAvailable else {
            throw NSError(
                domain: "HealthExport",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "This device does not support HealthKit"]
            )
        }

        var readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)!,
            HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)!,
            HKObjectType.workoutType()
        ]

        if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            readTypes.insert(wristTemp)
        }
        if let daylight = HKQuantityType.quantityType(forIdentifier: .timeInDaylight) {
            readTypes.insert(daylight)
        }

        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func snapshot(for day: Date) async throws -> HealthDaySnapshot {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)

        async let sleep = querySleep(predicate: predicate)
        async let heart = queryHeart(predicate: predicate)
        async let activity = queryActivity(predicate: predicate)
        async let body = queryBody(predicate: predicate)
        async let respiratory = queryRespiratory(predicate: predicate)
        async let audio = queryAudio(predicate: predicate)
        async let mindful = queryMindful(predicate: predicate)
        async let daylight = queryDaylight(predicate: predicate)
        async let workouts = queryWorkouts(predicate: predicate)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        return HealthDaySnapshot(
            date: dateFmt.string(from: dayStart),
            timezone: TimeZone.current.identifier,
            exportedAt: iso.string(from: Date()),
            sleep: try await sleep,
            heart: try await heart,
            activity: try await activity,
            body: try await body,
            respiratory: try await respiratory,
            audio: try await audio,
            mindful: try await mindful,
            daylight: try await daylight,
            workouts: try await workouts
        )
    }

    // MARK: - Category queries

    private func querySleep(predicate: NSPredicate) async throws -> HealthDaySnapshot.Sleep {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let samples = try await fetchCategorySamples(type: type, predicate: predicate)
        guard !samples.isEmpty else {
            return .init(inBedMinutes: nil, asleepMinutes: nil, asleepDeepMinutes: nil,
                         asleepCoreMinutes: nil, asleepRemMinutes: nil, awakeMinutes: nil)
        }

        var inBed = 0.0, asleep = 0.0, deep = 0.0, core = 0.0, rem = 0.0, awake = 0.0
        var hasInBed = false, hasAsleep = false
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBed += duration; hasInBed = true
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deep += duration; asleep += duration; hasAsleep = true
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                core += duration; asleep += duration; hasAsleep = true
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                rem += duration; asleep += duration; hasAsleep = true
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                asleep += duration; hasAsleep = true
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
            default:
                break
            }
        }
        return .init(
            inBedMinutes: hasInBed ? Int(inBed) : nil,
            asleepMinutes: hasAsleep ? Int(asleep) : nil,
            asleepDeepMinutes: deep > 0 ? Int(deep) : nil,
            asleepCoreMinutes: core > 0 ? Int(core) : nil,
            asleepRemMinutes: rem > 0 ? Int(rem) : nil,
            awakeMinutes: awake > 0 ? Int(awake) : nil
        )
    }

    private func queryHeart(predicate: NSPredicate) async throws -> HealthDaySnapshot.Heart {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let walkingType = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        let bpm = HKUnit(from: "count/min")
        let hrSamples = try await fetchQuantitySamples(type: hrType, predicate: predicate)
        let values = hrSamples.map { $0.quantity.doubleValue(for: bpm) }

        let resting = try await fetchLatestQuantity(type: restingType, predicate: predicate)?.doubleValue(for: bpm)
        let walking = try await fetchLatestQuantity(type: walkingType, predicate: predicate)?.doubleValue(for: bpm)
        let hrvMs = try await fetchLatestQuantity(type: hrvType, predicate: predicate)?
            .doubleValue(for: .secondUnit(with: .milli))

        return .init(
            restingBpm: resting.map { Int($0) },
            maxBpm: values.max().map { Int($0) },
            minBpm: values.min().map { Int($0) },
            avgBpm: values.isEmpty ? nil : Int(values.reduce(0, +) / Double(values.count)),
            hrvSdnnMs: hrvMs,
            walkingAvgBpm: walking.map { Int($0) },
            samplesCount: values.isEmpty ? nil : values.count
        )
    }

    private func queryActivity(predicate: NSPredicate) async throws -> HealthDaySnapshot.Activity {
        let steps = try await sumQuantity(.stepCount, unit: .count(), predicate: predicate)
        let dist = try await sumQuantity(.distanceWalkingRunning, unit: .meter(), predicate: predicate)
        let active = try await sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        let basal = try await sumQuantity(.basalEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        let exercise = try await sumQuantity(.appleExerciseTime, unit: .minute(), predicate: predicate)
        let stand = try await sumQuantity(.appleStandTime, unit: .minute(), predicate: predicate)
        let flights = try await sumQuantity(.flightsClimbed, unit: .count(), predicate: predicate)

        return .init(
            steps: steps.map { Int($0) },
            distanceKm: dist.map { $0 / 1000.0 },
            activeEnergyKcal: active,
            basalEnergyKcal: basal,
            exerciseMinutes: exercise.map { Int($0) },
            standHours: stand.map { Int($0 / 60.0) },
            flightsClimbed: flights.map { Int($0) }
        )
    }

    private func queryBody(predicate: NSPredicate) async throws -> HealthDaySnapshot.Body {
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let fatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!

        let weight = try await fetchLatestQuantity(type: weightType, predicate: predicate)?
            .doubleValue(for: .gramUnit(with: .kilo))
        let fat = try await fetchLatestQuantity(type: fatType, predicate: predicate)?
            .doubleValue(for: .percent())

        var wristTemp: Double?
        if let wristType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            wristTemp = try await fetchLatestQuantity(type: wristType, predicate: predicate)?
                .doubleValue(for: .degreeCelsius())
        }

        return .init(weightKg: weight, bodyFatPct: fat.map { $0 * 100 }, wristTempC: wristTemp)
    }

    private func queryRespiratory(predicate: NSPredicate) async throws -> HealthDaySnapshot.Respiratory {
        let spo2Type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let respRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max)!

        let spo2Samples = try await fetchQuantitySamples(type: spo2Type, predicate: predicate)
        let spo2Values = spo2Samples.map { $0.quantity.doubleValue(for: .percent()) * 100 }
        let spo2Avg: Double? = spo2Values.isEmpty ? nil : (spo2Values.reduce(0, +) / Double(spo2Values.count))

        let respSamples = try await fetchQuantitySamples(type: respRateType, predicate: predicate)
        let respValues = respSamples.map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }
        let respAvg: Double? = respValues.isEmpty ? nil : (respValues.reduce(0, +) / Double(respValues.count))

        let vo2 = try await fetchLatestQuantity(type: vo2Type, predicate: predicate)?
            .doubleValue(for: HKUnit(from: "ml/(kg*min)"))

        return .init(
            bloodOxygenPctAvg: spo2Avg,
            bloodOxygenSamplesCount: spo2Values.isEmpty ? nil : spo2Values.count,
            respiratoryRateAvg: respAvg,
            vo2Max: vo2
        )
    }

    private func queryAudio(predicate: NSPredicate) async throws -> HealthDaySnapshot.Audio {
        let envType = HKQuantityType.quantityType(forIdentifier: .environmentalAudioExposure)!
        let hpType = HKQuantityType.quantityType(forIdentifier: .headphoneAudioExposure)!
        let dbUnit = HKUnit.decibelAWeightedSoundPressureLevel()

        let envSamples = try await fetchQuantitySamples(type: envType, predicate: predicate)
        let envValues = envSamples.map { $0.quantity.doubleValue(for: dbUnit) }
        let envAvg: Double? = envValues.isEmpty ? nil : (envValues.reduce(0, +) / Double(envValues.count))

        let hpSamples = try await fetchQuantitySamples(type: hpType, predicate: predicate)
        let hpValues = hpSamples.map { $0.quantity.doubleValue(for: dbUnit) }
        let hpAvg: Double? = hpValues.isEmpty ? nil : (hpValues.reduce(0, +) / Double(hpValues.count))

        return .init(envSoundAvgDb: envAvg, envSoundMaxDb: envValues.max(), headphoneAvgDb: hpAvg)
    }

    private func queryMindful(predicate: NSPredicate) async throws -> HealthDaySnapshot.Mindful {
        let type = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        let samples = try await fetchCategorySamples(type: type, predicate: predicate)
        guard !samples.isEmpty else {
            return .init(minutes: nil, sessionsCount: nil)
        }
        let total = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
        return .init(minutes: Int(total), sessionsCount: samples.count)
    }

    private func queryDaylight(predicate: NSPredicate) async throws -> HealthDaySnapshot.Daylight {
        guard HKQuantityType.quantityType(forIdentifier: .timeInDaylight) != nil else {
            return .init(minutes: nil)
        }
        let minutes = try await sumQuantity(.timeInDaylight, unit: .minute(), predicate: predicate)
        return .init(minutes: minutes.map { Int($0) })
    }

    private func queryWorkouts(predicate: NSPredicate) async throws -> [HealthDaySnapshot.Workout] {
        let samples = try await fetchSamples(type: .workoutType(), predicate: predicate)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return samples.compactMap { $0 as? HKWorkout }.map { workout in
            HealthDaySnapshot.Workout(
                type: String(describing: workout.workoutActivityType),
                start: iso.string(from: workout.startDate),
                end: iso.string(from: workout.endDate),
                durationMinutes: Int(workout.duration / 60.0),
                distanceKm: workout.totalDistance.map { $0.doubleValue(for: .meter()) / 1000.0 },
                activeEnergyKcal: workout.totalEnergyBurned.map { $0.doubleValue(for: .kilocalorie()) },
                avgBpm: nil
            )
        }
    }

    // MARK: - Low-level helpers

    private func sumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    // "No data available" is not a real failure — means 0 samples for this type that day.
                    let ns = error as NSError
                    let noData = ns.code == HKError.errorNoData.rawValue
                        || ns.localizedDescription.contains("No data available")
                    if noData {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchLatestQuantity(type: HKQuantityType, predicate: NSPredicate) async throws -> HKQuantity? {
        let samples = try await fetchQuantitySamples(type: type, predicate: predicate)
        return samples.sorted { $0.endDate > $1.endDate }.first?.quantity
    }

    private func fetchQuantitySamples(type: HKQuantityType, predicate: NSPredicate) async throws -> [HKQuantitySample] {
        (try await fetchSamples(type: type, predicate: predicate)).compactMap { $0 as? HKQuantitySample }
    }

    private func fetchCategorySamples(type: HKCategoryType, predicate: NSPredicate) async throws -> [HKCategorySample] {
        (try await fetchSamples(type: type, predicate: predicate)).compactMap { $0 as? HKCategorySample }
    }

    private func fetchSamples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }
    }
}
