//
//  WalkingActivityReadAggregator.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import HealthKit

/// The walking metrics a single activity read can attempt.
enum WalkingMetric: Hashable, Sendable {
    case steps
    case activeCalories
    case distanceMeters
    case durationMinutes
    case averageHeartRate
}

/// Collapses per-metric read outcomes into one honest `WalkingActivityData`.
///
/// A metric missing from the outcomes was not requested and stays `nil`. A failed metric
/// also maps to `nil`, but only while at least one other metric read succeeded: a locked
/// database or a fully failed read throws instead, so callers never mistake a broken read
/// for an empty day.
enum WalkingActivityReadAggregator {

    /// Aggregates every attempted metric read for one day.
    ///
    /// - Parameters:
    ///   - date: The day the metrics were read for.
    ///   - outcomes: The result of every attempted metric read.
    /// - Returns: The aggregated walking activity for the day.
    /// - Throws: ``WalkingActivityReadError/databaseInaccessible`` when any metric failed
    ///   because the device is locked, or ``WalkingActivityReadError/allMetricsFailed(underlying:)``
    ///   when no attempted metric could be read.
    static func aggregate(date: Date, outcomes: [WalkingMetric: Result<Double?, any Error>]) throws -> WalkingActivityData {
        let failures = outcomes.values.compactMap { outcome -> (any Error)? in
            guard case .failure(let error) = outcome else { return nil }
            return error
        }

        if failures.contains(where: { $0.isHealthKitDatabaseInaccessible }) {
            throw WalkingActivityReadError.databaseInaccessible
        }

        if !outcomes.isEmpty, failures.count == outcomes.count {
            throw WalkingActivityReadError.allMetricsFailed(underlying: failures)
        }

        return WalkingActivityData(
            date: date,
            steps: value(of: .steps, in: outcomes),
            activeCalories: value(of: .activeCalories, in: outcomes),
            distanceMeters: value(of: .distanceMeters, in: outcomes),
            durationMinutes: value(of: .durationMinutes, in: outcomes),
            averageHeartRate: value(of: .averageHeartRate, in: outcomes)
        )
    }

    /// Extracts a successfully read value, treating failed or unattempted metrics as absent.
    private static func value(of metric: WalkingMetric, in outcomes: [WalkingMetric: Result<Double?, any Error>]) -> Double? {
        guard case .success(let value)? = outcomes[metric] else { return nil }
        return value
    }
}

extension Error {
    /// Whether HealthKit rejected the read because its database is encrypted behind the device lock.
    var isHealthKitDatabaseInaccessible: Bool {
        (self as? HKError)?.code == .errorDatabaseInaccessible
    }
}
