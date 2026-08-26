//
//  HKMWalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

internal extension HealthKitManager {

    /// Excludes manually entered samples, which the app must never credit as measured activity.
    func walkingActivityObserverPredicate() -> NSCompoundPredicate {
        let excludeManual = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [excludeManual])
    }

    /// Starts or stops observing walking activity changes using HKObserverQuery.
    ///
    /// Every background delivery is acknowledged after its processing finishes, on success
    /// and failure alike, so iOS never counts a delivery as missed and keeps waking the app.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when walking activity data changes.
    ///                 Returns `Result<WalkingActivityData?, Error>`.
    ///
    /// - Important: One delivery reports **twice**: the previous day first, then the current
    ///   day. Callers that submit what they receive must expect two callbacks per delivery
    ///   and decide separately what to do with the previous day.
    /// - Note: Transient observer failures are retried internally with backoff and never
    ///   reach `completion`. When the retries run out, observation stops and delivers
    ///   `HealthKitObservationError.observationStopped(afterConsecutiveFailures:lastError:)`
    ///   once; observing again re-arms it.
    /// - Note: Enable background delivery using `setBackgroundWalkingActivityUpdates(enabled:toRead:)`
    ///         to receive updates when the app is in the background.
    func observeWalkingActivityQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        observeQuery(
            start,
            coordinator: walkingActivityObservation,
            descriptors: { [weak self] in self?.walkingActivityObserverDescriptors() ?? [] },
            deliveryDates: { HealthKitDeliveryProcessor.deliveryDates(endingAt: Date()) },
            read: { [weak self] date in
                guard let self else { throw Permission.Error.unavailable }
                return try await self.readWalkingActivityMetrics(date: date, sampleTypes: self.walkingActivityBackgroundSampleTypes)
            },
            completion: completion
        )
    }

    /// The query descriptors the walking observer registers: one per metric type currently
    /// enabled for background delivery, so no delivery ever arrives without an observer to
    /// process and acknowledge it.
    func walkingActivityObserverDescriptors() -> [HKQueryDescriptor] {
        let predicate = walkingActivityObserverPredicate()
        return walkingActivityBackgroundTypes.map {
            HKQueryDescriptor(sampleType: $0, predicate: predicate)
        }
    }

    /// Reads walking activity for a date, requiring authorization to be established
    /// already and distinguishing missing samples from reads that failed.
    ///
    /// Never presents the permission sheet: asking the user is an explicit, user-initiated
    /// call, not a side effect of reading.
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The sample types whose metrics should be read.
    /// - Returns: The walking activity where `nil` metrics mean HealthKit has no samples.
    /// - Throws: ``WalkingActivityReadError`` when the read cannot be trusted, or a
    ///   `Permission.Error` when authorization was never established.
    func readWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async throws -> WalkingActivityData {
        try await requireEstablishedAuthorization(toRead: sampleTypes)
        return try await readWalkingActivityMetrics(date: date, sampleTypes: sampleTypes)
    }

    /// Reads every requested metric concurrently and aggregates the outcomes honestly,
    /// without touching authorization, so it is safe for background deliveries.
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The sample types whose metrics should be read.
    /// - Returns: The aggregated walking activity for the date.
    /// - Throws: ``WalkingActivityReadError`` when the read cannot be trusted, or
    ///   `Permission.Error.invalidParameters` when no supported metric was requested.
    func readWalkingActivityMetrics(date: Date, sampleTypes: Set<HKSampleType>) async throws -> WalkingActivityData {
        try WalkingActivityReadAggregator.aggregate(
            date: date,
            outcomes: await walkingActivityMetricOutcomes(date: date, sampleTypes: sampleTypes)
        )
    }

    /// Reads the requested metrics and degrades failures to absent values instead of
    /// failing the whole read, preserving whatever the day did produce.
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The sample types whose metrics should be read.
    /// - Returns: The walking activity, with failed metrics absent.
    func degradedWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData {
        WalkingActivityReadAggregator.lenientActivity(
            date: date,
            outcomes: await walkingActivityMetricOutcomes(date: date, sampleTypes: sampleTypes)
        )
    }

    /// Reads every requested metric concurrently, recording per-metric success or failure.
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The sample types whose metrics should be read.
    /// - Returns: One outcome per attempted metric; unsupported types are absent.
    private func walkingActivityMetricOutcomes(date: Date, sampleTypes: Set<HKSampleType>) async -> [WalkingMetric: Result<Double?, any Error>] {
        async let stepsOutcome = metricOutcome(attempted: sampleTypes.contains(HKQuantityType(.stepCount))) {
            try await self.getStepCount(date: date)
        }
        async let durationOutcome = metricOutcome(attempted: sampleTypes.contains(HKQuantityType(.stepCount))) {
            try await self.getTotalDurationInMinutes(date: date)
        }
        async let distanceOutcome = metricOutcome(attempted: sampleTypes.contains(HKQuantityType(.distanceWalkingRunning))) {
            try await self.getDistanceWalkingRunning(date: date, unit: .meter())
        }
        async let caloriesOutcome = metricOutcome(attempted: sampleTypes.contains(HKQuantityType(.activeEnergyBurned))) {
            try await self.getActiveEnergyBurned(date: date)
        }
        async let heartRateOutcome = metricOutcome(attempted: sampleTypes.contains(HKQuantityType(.heartRate))) {
            try await self.getAverageHeartRate(date: date)
        }

        var outcomes: [WalkingMetric: Result<Double?, any Error>] = [:]
        outcomes[.steps] = await stepsOutcome
        outcomes[.durationMinutes] = await durationOutcome
        outcomes[.distanceMeters] = await distanceOutcome
        outcomes[.activeCalories] = await caloriesOutcome
        outcomes[.averageHeartRate] = await heartRateOutcome
        return outcomes
    }

    /// Wraps a single metric read into an outcome, or `nil` when the metric was not requested.
    private func metricOutcome(
        attempted: Bool,
        read: @escaping @Sendable () async throws -> Double?
    ) async -> Result<Double?, any Error>? {
        guard attempted else { return nil }
        do {
            return .success(try await read())
        } catch {
            return .failure(error)
        }
    }
}
