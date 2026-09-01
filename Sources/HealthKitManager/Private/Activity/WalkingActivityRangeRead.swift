//
//  WalkingActivityRangeRead.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 01/09/26.
//

import Foundation
import HealthKit

/// One metric's answer for every day of a window, keyed by the start of each day.
/// A day the store knows nothing about is present with a `nil` value, which is the
/// same answer the per-day read gives for an empty day.
typealias WalkingMetricDayValues = [Date: Double?]

internal extension HealthKitManager {

    /// Reads every walking metric for a whole window, one query per metric.
    ///
    /// The per-day read asks HealthKit once per day per metric, so a thirty-day sweep
    /// costs about a hundred and twenty round trips and thirty authorization checks for a
    /// set of types that does not change while it runs. A statistics collection already
    /// buckets by day — that is what `intervalComponents` is for — so the same numbers
    /// come back from one query per metric, and duration comes from one sample query
    /// whose results are bucketed here.
    ///
    /// Authorization is established once, before the queries, rather than once per day.
    ///
    /// - Parameters:
    ///   - dates: The days to report. Need not be contiguous; the window spans the
    ///     earliest to the latest and only these days are answered.
    ///   - sampleTypes: The metrics to attempt.
    /// - Returns: Per metric, either the window's values by day or the failure that
    ///   stopped that metric. A metric that was not requested is absent.
    func walkingActivityRangeOutcomes(
        dates: [Date],
        sampleTypes: Set<HKSampleType>
    ) async -> [WalkingMetric: Result<WalkingMetricDayValues, any Error>] {
        let days = WalkingWindow.days(for: dates)
        guard let first = days.first, let last = days.last else { return [:] }

        do {
            try await statusForAuthorizationRequest(toWrite: [], toRead: sampleTypes)
        } catch {
            return Dictionary(
                uniqueKeysWithValues: WalkingMetric.walkingPayload
                    .filter { $0.isRequested(in: sampleTypes) }
                    .map { ($0, .failure(error)) }
            )
        }

        async let stepsOutcome = rangeOutcome(attempted: sampleTypes.contains(HKQuantityType(.stepCount))) {
            try await self.sumByDay(
                days: days, from: first, to: last,
                type: HKQuantityType(.stepCount), unit: .count()
            )
        }
        async let durationOutcome = rangeOutcome(attempted: sampleTypes.contains(HKQuantityType(.stepCount))) {
            try await self.walkingMinutesByDay(days: days, from: first, to: last)
        }
        async let distanceOutcome = rangeOutcome(attempted: sampleTypes.contains(HKQuantityType(.distanceWalkingRunning))) {
            try await self.sumByDay(
                days: days, from: first, to: last,
                type: HKQuantityType(.distanceWalkingRunning), unit: .meter()
            )
        }
        async let caloriesOutcome = rangeOutcome(attempted: sampleTypes.contains(HKQuantityType(.activeEnergyBurned))) {
            try await self.sumByDay(
                days: days, from: first, to: last,
                type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie()
            )
        }
        async let heartRateOutcome = rangeOutcome(attempted: sampleTypes.contains(HKQuantityType(.heartRate))) {
            try await self.averageByDay(
                days: days, from: first, to: last,
                type: HKQuantityType(.heartRate),
                unit: HKUnit.count().unitDivided(by: HKUnit.minute())
            )
        }

        var outcomes: [WalkingMetric: Result<WalkingMetricDayValues, any Error>] = [:]
        outcomes[.steps] = await stepsOutcome
        outcomes[.durationMinutes] = await durationOutcome
        outcomes[.distanceMeters] = await distanceOutcome
        outcomes[.activeCalories] = await caloriesOutcome
        outcomes[.averageHeartRate] = await heartRateOutcome
        return outcomes
    }

    private func rangeOutcome(
        attempted: Bool,
        read: @escaping @Sendable () async throws -> WalkingMetricDayValues
    ) async -> Result<WalkingMetricDayValues, any Error>? {
        guard attempted else { return nil }
        do {
            return .success(try await read())
        } catch {
            return .failure(error)
        }
    }

    /// A summed metric for every requested day, from one statistics collection query.
    private func sumByDay(
        days: [Date],
        from first: Date,
        to last: Date,
        type: HKQuantityType,
        unit: HKUnit
    ) async throws -> WalkingMetricDayValues {
        _ = try checkAuthorizationStatus(for: type)
        let collection = try await getDescriptor(
            startDate: first,
            endDate: WalkingWindow.end(of: last),
            type: type,
            options: .cumulativeSum
        ).result(for: healthStore)

        return days.reduce(into: WalkingMetricDayValues()) { values, day in
            values[day] = collection.statistics(for: day)?.sumQuantity()?.doubleValue(for: unit)
        }
    }

    /// An averaged metric for every requested day, from one statistics collection query.
    private func averageByDay(
        days: [Date],
        from first: Date,
        to last: Date,
        type: HKQuantityType,
        unit: HKUnit
    ) async throws -> WalkingMetricDayValues {
        _ = try checkAuthorizationStatus(for: type)
        let collection = try await getDescriptor(
            startDate: first,
            endDate: WalkingWindow.end(of: last),
            type: type,
            options: .discreteAverage
        ).result(for: healthStore)

        return days.reduce(into: WalkingMetricDayValues()) { values, day in
            values[day] = collection.statistics(for: day)?.averageQuantity()?.doubleValue(for: unit)
        }
    }

    /// Walking minutes for every requested day, from one sample query over the window.
    ///
    /// Duration is not a statistic: it is the union of the day's step-sample intervals,
    /// so overlapping recordings of one walk are not counted twice. The per-day read asks
    /// for a day's samples with a predicate that keeps any sample *overlapping* the day,
    /// so a walk crossing midnight belongs to both days it touches. Bucketing by the
    /// sample's start date would quietly drop it from the second day, so each day is given
    /// every sample that overlaps it, unclipped, exactly as the per-day predicate does.
    private func walkingMinutesByDay(
        days: [Date],
        from first: Date,
        to last: Date
    ) async throws -> WalkingMetricDayValues {
        let type = HKQuantityType(.stepCount)
        _ = try checkAuthorizationStatus(for: type)

        let samples = try await HKSampleQueryDescriptor(
            predicates: [
                .quantitySample(
                    type: type,
                    predicate: getPredicate(startDate: first, endDate: WalkingWindow.end(of: last))
                )
            ],
            sortDescriptors: []
        ).result(for: healthStore)

        let intervals = samples.map { DateInterval(start: $0.startDate, end: $0.endDate) }

        return days.reduce(into: WalkingMetricDayValues()) { values, day in
            values[day] = StepsDurationAggregator.totalMinutes(
                coveredBy: WalkingWindow.intervals(from: intervals, overlapping: day)
            )
        }
    }
}

extension WalkingMetric {

    /// The metrics a walking read attempts, in the order the payload lists them.
    static let walkingPayload: [WalkingMetric] = [
        .steps, .durationMinutes, .distanceMeters, .activeCalories, .averageHeartRate
    ]

    /// Whether a sweep over `sampleTypes` attempts this metric.
    func isRequested(in sampleTypes: Set<HKSampleType>) -> Bool {
        switch self {
        case .steps, .durationMinutes: return sampleTypes.contains(HKQuantityType(.stepCount))
        case .distanceMeters: return sampleTypes.contains(HKQuantityType(.distanceWalkingRunning))
        case .activeCalories: return sampleTypes.contains(HKQuantityType(.activeEnergyBurned))
        case .averageHeartRate: return sampleTypes.contains(HKQuantityType(.heartRate))
        }
    }
}

internal extension HealthKitManager {

    /// Reads a whole window and answers each requested day on its own terms.
    ///
    /// The window is read one query per metric. A metric whose range read failed is then
    /// re-read day by day, and only that metric: the point of the window read is speed,
    /// and the point of the per-day recovery is that a caller counting why days were
    /// skipped keeps being able to tell one day from another. Without it a single failed
    /// query would report thirty unexplained days.
    ///
    /// A locked store is the exception that skips recovery. It cannot answer any day, so
    /// re-reading thirty times would produce thirty identical refusals and nothing else.
    ///
    /// - Parameters:
    ///   - dates: The days to report.
    ///   - sampleTypes: The metrics to attempt.
    /// - Returns: Each requested day mapped to its activity, or to the failure that
    ///   stopped it — the same verdicts the per-day read produces.
    func readWalkingActivityWindow(
        dates: [Date],
        sampleTypes: Set<HKSampleType>
    ) async -> [Date: Result<WalkingActivityData, any Error>] {
        let days = WalkingWindow.days(for: dates)
        guard !days.isEmpty else { return [:] }

        var byMetric = await walkingActivityRangeOutcomes(dates: days, sampleTypes: sampleTypes)

        if byMetric.values.contains(where: { if case .failure(let error) = $0 { return error.isHealthKitDatabaseInaccessible } else { return false } }) {
            return days.reduce(into: [:]) { results, day in
                results[day] = .failure(WalkingActivityReadError.databaseInaccessible)
            }
        }

        for (metric, outcome) in byMetric {
            guard case .failure = outcome else { continue }
            byMetric[metric] = .success(await recoverPerDay(metric: metric, days: days))
        }

        return days.reduce(into: [:]) { results, day in
            let outcomes = dayOutcomes(day: day, from: byMetric)
            do {
                results[day] = .success(try WalkingActivityReadAggregator.aggregate(date: day, outcomes: outcomes))
            } catch {
                results[day] = .failure(error)
            }
        }
    }

    /// Re-reads one metric a day at a time, keeping each day's own failure.
    private func recoverPerDay(metric: WalkingMetric, days: [Date]) async -> WalkingMetricDayValues {
        var values = WalkingMetricDayValues()
        for day in days {
            values[day] = try? await perDayRead(metric: metric, date: day)
        }
        return values
    }

    private func perDayRead(metric: WalkingMetric, date: Date) async throws -> Double? {
        switch metric {
        case .steps: return try await getStepCount(date: date)
        case .durationMinutes: return try await getTotalDurationInMinutes(date: date)
        case .distanceMeters: return try await getDistanceWalkingRunning(date: date, unit: .meter())
        case .activeCalories: return try await getActiveEnergyBurned(date: date)
        case .averageHeartRate: return try await getAverageHeartRate(date: date)
        }
    }

    /// One day's per-metric outcomes, in the shape the aggregator already judges.
    private func dayOutcomes(
        day: Date,
        from byMetric: [WalkingMetric: Result<WalkingMetricDayValues, any Error>]
    ) -> [WalkingMetric: Result<Double?, any Error>] {
        byMetric.reduce(into: [:]) { outcomes, entry in
            switch entry.value {
            case .success(let values): outcomes[entry.key] = .success(values[day] ?? nil)
            case .failure(let error): outcomes[entry.key] = .failure(error)
            }
        }
    }
}
