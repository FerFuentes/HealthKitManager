//
//  HealthKitObservationCoordinator.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Owns the lifecycle of one background observation: which subscriber is listening, which
/// query is currently registered, and how failures are retried.
///
/// HealthKit delivers on its own queue while the app starts and stops observation from
/// elsewhere, so every piece of that state lives behind one lock. Deliveries are matched
/// against the registered query, which makes a callback from a replaced query identifiable
/// and ignorable rather than a cause of spurious restarts.
final class HealthKitObservationCoordinator<Activity: Sendable>: @unchecked Sendable {

    typealias Subscriber = @Sendable (Result<Activity?, any Error>) -> Void

    /// What the observer must do with a delivery that carried no error.
    enum DeliveryHandling {
        case ignore
        case process(Subscriber)
    }

    /// What the observer must do with a delivery that carried an error.
    enum FailureHandling {
        case retrySilently
        case reportTerminal(HealthKitObservationError, Subscriber)
    }

    private let lock = NSLock()
    private let scheduleRestart: @Sendable (Duration, @escaping @Sendable () -> Void) -> Void
    private var subscriber: Subscriber?
    private var registerQuery: (@Sendable () -> AnyObject?)?
    private var haltQuery: (@Sendable (AnyObject) -> Void)?
    private var activeQuery: AnyObject?
    private var consecutiveFailures = 0

    /// - Parameter scheduleRestart: Runs a re-registration after a backoff. Injected so
    ///   tests drive the retry sequence without waiting for real time to pass.
    init(scheduleRestart: @escaping @Sendable (Duration, @escaping @Sendable () -> Void) -> Void = { delay, restart in
        Task {
            try? await Task.sleep(for: delay)
            restart()
        }
    }) {
        self.scheduleRestart = scheduleRestart
    }

    var isObserving: Bool {
        lock.withLock { subscriber != nil }
    }

    /// Starts observing, registering the query and remembering how to rebuild it.
    ///
    /// - Parameters:
    ///   - subscriber: Receives every delivery outcome until observation stops.
    ///   - register: Registers a query with the health store and returns it.
    ///   - halt: Stops a previously registered query.
    func startObserving(
        subscriber: @escaping Subscriber,
        register: @escaping @Sendable () -> AnyObject?,
        halt: @escaping @Sendable (AnyObject) -> Void
    ) {
        lock.withLock {
            guard self.subscriber == nil else { return }
            self.subscriber = subscriber
            self.registerQuery = register
            self.haltQuery = halt
            self.consecutiveFailures = 0
            self.activeQuery = register()
        }
    }

    /// Stops observing and releases the registered query.
    func stopObserving() {
        lock.withLock {
            subscriber = nil
            consecutiveFailures = 0
            haltActiveQuery()
        }
    }

    /// Decides how to handle a delivery that arrived without an error.
    ///
    /// - Parameter query: The query that delivered, used to reject stale callbacks.
    /// - Returns: The subscriber to report to, or `ignore` for a stale delivery.
    func handling(forDeliveryFrom query: AnyObject) -> DeliveryHandling {
        lock.withLock {
            guard activeQuery === query, let subscriber else { return .ignore }
            consecutiveFailures = 0
            return .process(subscriber)
        }
    }

    /// Decides how to handle a delivery that carried an error, scheduling a retry while
    /// the policy allows one and surfacing a terminal signal when it does not.
    ///
    /// - Parameters:
    ///   - query: The query that delivered, used to reject stale callbacks.
    ///   - error: The failure HealthKit reported.
    /// - Returns: Whether the failure is being retried silently or ends observation.
    func handling(forFailedDeliveryFrom query: AnyObject, error: any Error) -> FailureHandling {
        var terminalSubscriber: Subscriber?
        var toleratedFailures = 0

        let restartDelay: Duration? = lock.withLock {
            guard activeQuery === query, let currentSubscriber = subscriber else { return nil }

            haltActiveQuery()
            consecutiveFailures += 1

            guard let delay = HealthKitObservationRetryPolicy.restartDelay(afterConsecutiveFailures: consecutiveFailures) else {
                terminalSubscriber = currentSubscriber
                toleratedFailures = consecutiveFailures
                subscriber = nil
                consecutiveFailures = 0
                return nil
            }

            return delay
        }

        if let restartDelay {
            scheduleRestart(restartDelay) { [weak self] in
                self?.reregisterAfterBackoff()
            }
            return .retrySilently
        }

        guard let terminalSubscriber else { return .retrySilently }

        return .reportTerminal(
            .observationStopped(afterConsecutiveFailures: toleratedFailures, lastError: error),
            terminalSubscriber
        )
    }

    /// Rebuilds the registered query against the descriptors as they are now, when something
    /// the descriptors are derived from has changed. Does nothing when not observing, so the
    /// next `startObserving` picks the new descriptors up anyway.
    func reregisterIfObserving() {
        lock.withLock {
            guard subscriber != nil, let registerQuery else { return }
            haltActiveQuery()
            activeQuery = registerQuery()
        }
    }

    /// Re-registers the query once a backoff elapses, unless observation stopped meanwhile.
    private func reregisterAfterBackoff() {
        lock.withLock {
            guard subscriber != nil, activeQuery == nil, let registerQuery else { return }
            activeQuery = registerQuery()
        }
    }

    /// Stops and releases the registered query. Callers must hold `lock`.
    private func haltActiveQuery() {
        guard let activeQuery, let haltQuery else { return }
        haltQuery(activeQuery)
        self.activeQuery = nil
    }
}
