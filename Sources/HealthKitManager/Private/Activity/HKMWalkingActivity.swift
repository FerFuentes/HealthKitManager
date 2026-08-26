//
//  HKMWalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

internal extension HealthKitManager {

    func getPredicateForWalkingActivityAnchorQuery() -> NSCompoundPredicate {
        let excludeManual = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [excludeManual])
    }

    var walkingActivityAnchorQuery: HKQueryAnchor? {
        get {
            if let anchorData = UserDefaults.standard.data(forKey: "walkingActivityAnchor") {
                return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
            }
            return nil
        }
        set {
            if let newAnchor = newValue {
                let anchorData = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                UserDefaults.standard.set(anchorData, forKey: "walkingActivityAnchor")
            } else {
                UserDefaults.standard.removeObject(forKey: "walkingActivityAnchor")
            }
        }
    }

    func walkingActivityAnchoredObjectQuery(
        _ start: Bool,
        toRead: Set<HKQuantityType>,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        if start {
            guard (walkingActivityAnchoredQuery == nil) else {
                return
            }

            let predicate = getPredicateForWalkingActivityAnchorQuery()
            let queryDescriptors = toRead.map {
                HKQueryDescriptor(sampleType: $0, predicate: predicate)
            }

            let handleSamples: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { [weak self] _, samples, _, newAnchor, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let samples = samples, !samples.isEmpty else {
                    completion(.success(nil))
                    return
                }

                Task {
                    self.walkingActivityAnchorQuery = newAnchor

                    do {
                        let activity = try await self.readWalkingActivityMetrics(date: Date(), sampleTypes: self.forWalkingActivityQuantityType)
                        completion(.success(activity))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }

            let query = HKAnchoredObjectQuery(
                queryDescriptors: queryDescriptors,
                anchor: walkingActivityAnchorQuery,
                limit: HKObjectQueryNoLimit,
                resultsHandler: handleSamples
            )

            query.updateHandler = handleSamples
            healthStore.execute(query)

            walkingActivityAnchoredQuery = query
        } else {
            if let query = walkingActivityAnchoredQuery {
                healthStore.stop(query)
                walkingActivityAnchoredQuery = nil
            }
        }
    }

    /// Starts or stops observing walking activity changes using HKObserverQuery.
    ///
    /// Every background delivery is acknowledged after its processing finishes, on success
    /// and failure alike, so iOS never counts a delivery as missed and keeps waking the app.
    /// A failing observer query is stopped and re-registered instead of going dark.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when walking activity data changes.
    ///                 Returns `Result<WalkingActivityData?, Error>`.
    ///
    /// - Note: Enable background delivery using `enableBackgroundWalkingActivityUpdates(enabled:)`
    ///         to receive updates when the app is in the background.
    func observeWalkingActivityQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        if start {
            guard (walkingActivityObserverQuery == nil) else {
                return
            }
            startWalkingActivityObserver(completion: completion)
        } else {
            stopWalkingActivityObserver()
        }
    }

    /// Registers the observer query whose handler acknowledges the current delivery on every path.
    private func startWalkingActivityObserver(
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        let predicate = getPredicateForWalkingActivityAnchorQuery()
        let query = HKObserverQuery(
            sampleType: HKQuantityType(.stepCount),
            predicate: predicate) { [weak self] _, deliveryCompletionHandler, error in
                nonisolated(unsafe) let acknowledgeDelivery = deliveryCompletionHandler

                guard let self = self else {
                    acknowledgeDelivery()
                    return
                }

                if let error = error {
                    acknowledgeDelivery()
                    self.restartWalkingActivityObserver(completion: completion)
                    completion(.failure(error))
                } else {
                    Task {
                        await WalkingActivityDeliveryHandler.processDelivery(
                            read: { try await self.readWalkingActivityMetrics(date: Date(), sampleTypes: self.forWalkingActivityQuantityType) },
                            report: completion,
                            acknowledge: { acknowledgeDelivery() }
                        )
                    }
                }
            }

        healthStore.execute(query)
        walkingActivityObserverQuery = query
    }

    private func stopWalkingActivityObserver() {
        guard let query = walkingActivityObserverQuery else { return }
        healthStore.stop(query)
        walkingActivityObserverQuery = nil
    }

    /// Replaces a failed observer query with a fresh registration so observation keeps running.
    private func restartWalkingActivityObserver(
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        stopWalkingActivityObserver()
        startWalkingActivityObserver(completion: completion)
    }

    /// Reads walking activity for a date, requesting authorization first and
    /// distinguishing missing samples from reads that failed.
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The sample types whose metrics should be read.
    /// - Returns: The walking activity where `nil` metrics mean HealthKit has no samples.
    /// - Throws: ``WalkingActivityReadError`` when the read cannot be trusted, or a
    ///   `Permission.Error` when authorization cannot be established.
    func readWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async throws -> WalkingActivityData {
        try await statusForAuthorizationRequest(toWrite: [], toRead: sampleTypes)
        return try await readWalkingActivityMetrics(date: date, sampleTypes: sampleTypes)
    }

    /// Reads every requested metric concurrently and aggregates the outcomes honestly,
    /// without triggering an authorization request, so it is safe for background deliveries.
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The sample types whose metrics should be read.
    /// - Returns: The aggregated walking activity for the date.
    /// - Throws: ``WalkingActivityReadError`` when the read cannot be trusted.
    func readWalkingActivityMetrics(date: Date, sampleTypes: Set<HKSampleType>) async throws -> WalkingActivityData {
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

        return try WalkingActivityReadAggregator.aggregate(date: date, outcomes: outcomes)
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
