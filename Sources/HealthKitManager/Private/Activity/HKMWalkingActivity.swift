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
    /// A failing observer query is re-registered with a bounded exponential backoff instead
    /// of going dark or spinning a hot register/error loop.
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
        walkingActivityObserverLock.withLock {
            if start {
                guard walkingActivitySubscriber == nil else { return }
                walkingActivitySubscriber = completion
                walkingActivityObserverConsecutiveFailures = 0
                registerWalkingActivityObserver()
            } else {
                walkingActivitySubscriber = nil
                haltWalkingActivityObserver()
            }
        }
    }

    /// The query descriptors the walking observer registers: one per metric type the
    /// package enables for background delivery by default, so no delivery ever arrives
    /// without an observer to process and acknowledge it.
    func walkingActivityObserverDescriptors() -> [HKQueryDescriptor] {
        let predicate = getPredicateForWalkingActivityAnchorQuery()
        return forWalkingActivityQuantityType.map {
            HKQueryDescriptor(sampleType: $0, predicate: predicate)
        }
    }

    /// Registers the observer query whose handler acknowledges the current delivery on
    /// every path. Callers must hold `walkingActivityObserverLock`.
    private func registerWalkingActivityObserver() {
        let query = HKObserverQuery(
            queryDescriptors: walkingActivityObserverDescriptors()) { [weak self] _, _, deliveryCompletionHandler, error in
                nonisolated(unsafe) let acknowledgeDelivery = deliveryCompletionHandler

                guard let self = self else {
                    acknowledgeDelivery()
                    return
                }

                guard let subscriber = self.walkingActivityObserverLock.withLock({ self.walkingActivitySubscriber }) else {
                    acknowledgeDelivery()
                    return
                }

                if let error = error {
                    acknowledgeDelivery()
                    self.scheduleWalkingActivityObserverRestart()
                    subscriber(.failure(error))
                } else {
                    self.walkingActivityObserverLock.withLock {
                        self.walkingActivityObserverConsecutiveFailures = 0
                    }
                    Task {
                        await WalkingActivityDeliveryHandler.processDelivery(
                            read: { try await self.readWalkingActivityMetrics(date: Date(), sampleTypes: self.forWalkingActivityQuantityType) },
                            report: subscriber,
                            acknowledge: { acknowledgeDelivery() }
                        )
                    }
                }
            }

        healthStore.execute(query)
        walkingActivityObserverQuery = query
    }

    /// Stops and releases the active observer query. Callers must hold `walkingActivityObserverLock`.
    private func haltWalkingActivityObserver() {
        guard let query = walkingActivityObserverQuery else { return }
        healthStore.stop(query)
        walkingActivityObserverQuery = nil
    }

    /// Stops the failed observer and re-registers it after a bounded backoff, giving up
    /// once the retry policy is exhausted, and never re-registering after the subscriber
    /// stopped observing.
    private func scheduleWalkingActivityObserverRestart() {
        let restartDelay: Duration? = walkingActivityObserverLock.withLock {
            haltWalkingActivityObserver()
            walkingActivityObserverConsecutiveFailures += 1
            return WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: walkingActivityObserverConsecutiveFailures)
        }

        guard let restartDelay else { return }

        Task {
            try? await Task.sleep(for: restartDelay)
            walkingActivityObserverLock.withLock {
                guard walkingActivitySubscriber != nil, walkingActivityObserverQuery == nil else { return }
                registerWalkingActivityObserver()
            }
        }
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
