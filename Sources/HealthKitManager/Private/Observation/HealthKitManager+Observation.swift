//
//  HealthKitManager+Observation.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import HealthKit

internal extension HealthKitManager {

    /// Starts or stops one background observation, applying the delivery contract every
    /// observer in this package owes HealthKit: acknowledge each delivery once, after
    /// processing; ignore deliveries from a query that was already replaced; retry
    /// transient failures with backoff without bothering the subscriber; and report the
    /// terminal signal once when the retries run out.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - coordinator: Owns this observation's lifecycle state.
    ///   - descriptors: The query descriptors to register, evaluated at each registration.
    ///   - read: Produces the activity for the day a delivery woke on, or `nil` when that
    ///     day has nothing to report.
    ///   - completion: Receives every outcome until observation stops.
    func observeQuery<Activity: Sendable>(
        _ start: Bool,
        coordinator: HealthKitObservationCoordinator<Activity>,
        descriptors: @escaping @Sendable () -> [HKQueryDescriptor],
        read: @escaping @Sendable (Date) async throws -> Activity?,
        completion: @escaping @Sendable (Result<Activity?, Error>) -> Void
    ) {
        guard start else {
            coordinator.stopObserving()
            return
        }

        coordinator.startObserving(
            subscriber: completion,
            register: { [weak self] in
                guard let self else { return nil }
                return self.executeObserverQuery(coordinator: coordinator, descriptors: descriptors(), read: read)
            },
            halt: { [weak self] query in
                guard let self, let query = query as? HKObserverQuery else { return }
                self.healthStore.stop(query)
            }
        )
    }

    /// Registers one observer query wired to the coordinator's decisions.
    private func executeObserverQuery<Activity: Sendable>(
        coordinator: HealthKitObservationCoordinator<Activity>,
        descriptors: [HKQueryDescriptor],
        read: @escaping @Sendable (Date) async throws -> Activity?
    ) -> HKObserverQuery {
        let query = HKObserverQuery(queryDescriptors: descriptors) { query, _, deliveryCompletionHandler, error in
            nonisolated(unsafe) let acknowledgeDelivery = deliveryCompletionHandler
            let deliveredAt = Date()

            if let error = error {
                switch coordinator.handling(forFailedDeliveryFrom: query, error: error) {
                case .retrySilently:
                    acknowledgeDelivery()
                case .reportTerminal(let terminal, let subscriber):
                    acknowledgeDelivery()
                    subscriber(.failure(terminal))
                }
                return
            }

            switch coordinator.handling(forDeliveryFrom: query) {
            case .ignore:
                acknowledgeDelivery()
            case .process(let subscriber):
                Task {
                    await HealthKitDeliveryProcessor.processDelivery(
                        date: deliveredAt,
                        read: read,
                        report: subscriber,
                        acknowledge: { acknowledgeDelivery() }
                    )
                }
            }
        }

        healthStore.execute(query)
        return query
    }
}
