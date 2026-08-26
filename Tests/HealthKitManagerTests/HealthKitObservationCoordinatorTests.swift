//
//  HealthKitObservationCoordinatorTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import Testing
@testable import HealthKitManager

/// Tests for the observation lifecycle: retry policy, stale-delivery rejection,
/// the terminal signal and re-arming after observation gave up.
struct HealthKitObservationCoordinatorTests {

    private struct ObserverFailure: Error {}

    private final class StubQuery {}

    /// Drives registrations, halts and pending backoff restarts without real time passing.
    private final class ObservationHarness: @unchecked Sendable {
        private let lock = NSLock()
        private var registered: [StubQuery] = []
        private var halted: [StubQuery] = []
        private var pendingRestarts: [@Sendable () -> Void] = []
        private(set) var scheduledDelays: [Duration] = []
        private var reported: [Result<Int?, any Error>] = []

        lazy var coordinator = HealthKitObservationCoordinator<Int>(scheduleRestart: { [weak self] delay, restart in
            guard let self else { return }
            self.lock.withLock {
                self.scheduledDelays.append(delay)
                self.pendingRestarts.append(restart)
            }
        })

        func start() {
            coordinator.startObserving(
                subscriber: { [weak self] outcome in
                    self?.lock.withLock { self?.reported.append(outcome) }
                },
                register: { [weak self] in
                    guard let self else { return nil }
                    let query = StubQuery()
                    self.lock.withLock { self.registered.append(query) }
                    return query
                },
                halt: { [weak self] query in
                    guard let self, let query = query as? StubQuery else { return }
                    self.lock.withLock { self.halted.append(query) }
                }
            )
        }

        func runPendingRestarts() {
            let restarts = lock.withLock {
                let pending = pendingRestarts
                pendingRestarts = []
                return pending
            }
            restarts.forEach { $0() }
        }

        var currentQuery: StubQuery? { lock.withLock { registered.last } }
        var registrationCount: Int { lock.withLock { registered.count } }
        var haltCount: Int { lock.withLock { halted.count } }
        var reportedFailures: [any Error] {
            lock.withLock { reported.compactMap { if case .failure(let error) = $0 { return error } else { return nil } } }
        }
    }

    @Test func staleDeliveryIsIgnoredWithoutTouchingObservation() {
        let harness = ObservationHarness()
        harness.start()
        let replacedQuery = StubQuery()

        if case .process = harness.coordinator.handling(forDeliveryFrom: replacedQuery) {
            Issue.record("A delivery from a replaced query must not be processed")
        }

        if case .reportTerminal = harness.coordinator.handling(forFailedDeliveryFrom: replacedQuery, error: ObserverFailure()) {
            Issue.record("A failure from a replaced query must not end observation")
        }

        #expect(harness.haltCount == 0)
        #expect(harness.registrationCount == 1)
        #expect(harness.coordinator.isObserving)
    }

    @Test func deliveryFromTheRegisteredQueryIsProcessed() {
        let harness = ObservationHarness()
        harness.start()

        guard let query = harness.currentQuery else {
            Issue.record("Observation did not register a query")
            return
        }

        if case .ignore = harness.coordinator.handling(forDeliveryFrom: query) {
            Issue.record("A delivery from the registered query must be processed")
        }
    }

    @Test func failuresRetrySilentlyWithBackoffBeforeGivingUp() {
        let harness = ObservationHarness()
        harness.start()

        for _ in 1...HealthKitObservationRetryPolicy.maximumConsecutiveFailures {
            guard let query = harness.currentQuery else {
                Issue.record("Observation stopped re-registering too early")
                return
            }
            guard case .retrySilently = harness.coordinator.handling(forFailedDeliveryFrom: query, error: ObserverFailure()) else {
                Issue.record("Failures within the policy must be retried silently")
                return
            }
            harness.runPendingRestarts()
        }

        #expect(harness.scheduledDelays == [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(16)])
        #expect(harness.reportedFailures.isEmpty)
    }

    @Test func exhaustedRetriesReportTheTerminalSignalOnce() {
        let harness = ObservationHarness()
        harness.start()

        for _ in 1...HealthKitObservationRetryPolicy.maximumConsecutiveFailures {
            guard let query = harness.currentQuery else { return }
            _ = harness.coordinator.handling(forFailedDeliveryFrom: query, error: ObserverFailure())
            harness.runPendingRestarts()
        }

        guard let finalQuery = harness.currentQuery else {
            Issue.record("Observation did not re-register for the final attempt")
            return
        }

        guard case .reportTerminal(let terminal, let subscriber) = harness.coordinator.handling(forFailedDeliveryFrom: finalQuery, error: ObserverFailure()) else {
            Issue.record("Exhausted retries must report a terminal signal")
            return
        }

        guard case .observationStopped(let failures, _) = terminal else {
            Issue.record("Expected observationStopped")
            return
        }
        #expect(failures == HealthKitObservationRetryPolicy.maximumConsecutiveFailures + 1)

        subscriber(.failure(terminal))
        #expect(harness.reportedFailures.count == 1)
        #expect(!harness.coordinator.isObserving)
    }

    @Test func observationCanBeRearmedAfterItGaveUp() {
        let harness = ObservationHarness()
        harness.start()

        for _ in 1...(HealthKitObservationRetryPolicy.maximumConsecutiveFailures + 1) {
            guard let query = harness.currentQuery else { break }
            _ = harness.coordinator.handling(forFailedDeliveryFrom: query, error: ObserverFailure())
            harness.runPendingRestarts()
        }

        #expect(!harness.coordinator.isObserving)
        let registrationsBeforeRearm = harness.registrationCount

        harness.start()

        #expect(harness.coordinator.isObserving)
        #expect(harness.registrationCount == registrationsBeforeRearm + 1)
    }

    @Test func stoppingDuringBackoffPreventsReregistration() {
        let harness = ObservationHarness()
        harness.start()

        guard let query = harness.currentQuery else { return }
        _ = harness.coordinator.handling(forFailedDeliveryFrom: query, error: ObserverFailure())
        let registrationsBeforeStop = harness.registrationCount

        harness.coordinator.stopObserving()
        harness.runPendingRestarts()

        #expect(harness.registrationCount == registrationsBeforeStop)
        #expect(!harness.coordinator.isObserving)
    }

    @Test func successfulDeliveryResetsTheFailureCount() {
        let harness = ObservationHarness()
        harness.start()

        for _ in 1...3 {
            guard let query = harness.currentQuery else { return }
            _ = harness.coordinator.handling(forFailedDeliveryFrom: query, error: ObserverFailure())
            harness.runPendingRestarts()
        }

        guard let recoveredQuery = harness.currentQuery else { return }
        _ = harness.coordinator.handling(forDeliveryFrom: recoveredQuery)

        guard case .retrySilently = harness.coordinator.handling(forFailedDeliveryFrom: recoveredQuery, error: ObserverFailure()) else {
            Issue.record("A recovered observation must start its retry budget over")
            return
        }
        #expect(harness.scheduledDelays.last == .seconds(1))
    }
}
