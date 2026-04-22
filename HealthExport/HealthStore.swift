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

        let readTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKObjectType.workoutType()
        ]

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
            workouts: try await workouts
        )
    }

    // MARK: - Category queries

    private func querySleep(predicate: NSPredicate) async throws -> HealthDaySnapshot.Sleep? {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let samples = try await fetchCategorySamples(type: type, predicate: predicate)
        guard !samples.isEmpty else { return nil }

        var inBedMinutes = 0.0
        var asleepMinutes = 0.0
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                inBedMinutes += duration
            } else if asleepValues.contains(sample.value) {
                asleepMinutes += duration
            }
        }
        return .init(inBedMinutes: Int(inBedMinutes), asleepMinutes: Int(asleepMinutes))
    }

    private func queryHeart(predicate: NSPredicate) async throws -> HealthDaySnapshot.Heart? {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let restingType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        let bpmUnit = HKUnit(from: "count/min")
        let hrSamples = try await fetchQuantitySamples(type: hrType, predicate: predicate)
        let hrValues = hrSamples.map { $0.quantity.doubleValue(for: bpmUnit) }

        let resting = try await fetchLatestQuantity(type: restingType, predicate: predicate)?.doubleValue(for: bpmUnit)
        let hrvMs = try await fetchLatestQuantity(type: hrvType, predicate: predicate)?
            .doubleValue(for: .secondUnit(with: .milli))

        guard !hrValues.isEmpty || resting != nil || hrvMs != nil else { return nil }

        return .init(
            restingBpm: resting.map { Int($0) },
            maxBpm: hrValues.max().map { Int($0) },
            avgBpm: hrValues.isEmpty ? nil : Int(hrValues.reduce(0, +) / Double(hrValues.count)),
            hrvSdnnMs: hrvMs,
            samplesCount: hrValues.count
        )
    }

    private func queryActivity(predicate: NSPredicate) async throws -> HealthDaySnapshot.Activity? {
        let steps = try await sumQuantity(.stepCount, unit: .count(), predicate: predicate)
        let dist = try await sumQuantity(.distanceWalkingRunning, unit: .meter(), predicate: predicate)
        let active = try await sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), predicate: predicate)
        let exercise = try await sumQuantity(.appleExerciseTime, unit: .minute(), predicate: predicate)
        let stand = try await sumQuantity(.appleStandTime, unit: .minute(), predicate: predicate)

        if steps == nil && dist == nil && active == nil && exercise == nil && stand == nil { return nil }

        return .init(
            steps: steps.map { Int($0) },
            distanceKm: dist.map { $0 / 1000.0 },
            activeEnergyKcal: active,
            exerciseMinutes: exercise.map { Int($0) },
            standHours: stand.map { Int($0 / 60.0) }
        )
    }

    private func queryBody(predicate: NSPredicate) async throws -> HealthDaySnapshot.Body? {
        let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let fatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!

        let weight = try await fetchLatestQuantity(type: weightType, predicate: predicate)?
            .doubleValue(for: .gramUnit(with: .kilo))
        let fat = try await fetchLatestQuantity(type: fatType, predicate: predicate)?
            .doubleValue(for: .percent())

        if weight == nil && fat == nil { return nil }
        return .init(weightKg: weight, bodyFatPct: fat.map { $0 * 100 })
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
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
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
