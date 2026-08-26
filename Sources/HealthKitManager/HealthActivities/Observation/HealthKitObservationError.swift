//
//  HealthKitObservationError.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Terminal failures of a background observation, delivered to the subscriber once.
///
/// Transient observer failures are retried internally with backoff and never reach the
/// subscriber. When the retries run out, observation stops and this arrives instead, so
/// callers can report it and decide to observe again.
public enum HealthKitObservationError: Error {
    /// Observation stopped after the retry policy was exhausted.
    ///
    /// - Parameters:
    ///   - afterConsecutiveFailures: How many consecutive failures were tolerated first.
    ///   - lastError: The failure reported by the final attempt.
    case observationStopped(afterConsecutiveFailures: Int, lastError: any Error)
}

extension HealthKitObservationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .observationStopped(let failures, let lastError):
            return "Background observation stopped after \(failures) consecutive failures. Last error: \(lastError.localizedDescription)"
        }
    }
}
