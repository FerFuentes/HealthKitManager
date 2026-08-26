//
//  WalkingActivityObserverRetryPolicy.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Bounds how a failed walking activity observer is re-registered: exponential backoff
/// between attempts and a hard cap, so a persistent error such as revoked authorization
/// cannot spin a hot register/error loop.
enum WalkingActivityObserverRetryPolicy {

    static let maximumConsecutiveFailures = 5

    /// The pause before re-registering the observer after a run of consecutive failures.
    ///
    /// - Parameter failures: How many times in a row the observer has failed.
    /// - Returns: The backoff to wait before the next registration, or `nil` when the
    ///   policy is exhausted and observation must stay stopped until restarted explicitly.
    static func restartDelay(afterConsecutiveFailures failures: Int) -> Duration? {
        guard failures >= 1, failures <= maximumConsecutiveFailures else { return nil }
        return .seconds(1 << (failures - 1))
    }
}
