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
/// also maps to `nil`, but only while another metric actually produced a value: a locked
/// database, a read that attempted nothing, or a read whose every value came back empty
/// alongside failures throws instead, so callers never mistake a broken read for an empty day.
enum WalkingActivityReadAggregator {

    /// Aggregates every attempted metric read for one day, refusing to return data that
    /// cannot be told apart from a genuinely empty day.
    ///
    /// - Parameters:
    ///   - date: The day the metrics were read for.
    ///   - outcomes: The result of every attempted metric read.
    /// - Returns: The aggregated walking activity for the day.
    /// - Throws: `Permission.Error.invalidParameters` when nothing was attempted,
    ///   ``WalkingActivityReadError/databaseInaccessible`` when the device is locked, or
    ///   ``WalkingActivityReadError/allMetricsFailed(underlying:)`` when no metric produced a value.
    static func aggregate(date: Date, outcomes: [WalkingMetric: Result<Double?, any Error>]) throws -> WalkingActivityData {
        guard !outcomes.isEmpty else {
            throw Permission.Error.invalidParameters("No supported walking metric was requested.")
        }

        let failures = outcomes.values.compactMap { outcome -> (any Error)? in
            guard case .failure(let error) = outcome else { return nil }
            return error
        }

        if failures.contains(where: { $0.isHealthKitDatabaseInaccessible }) {
            throw WalkingActivityReadError.databaseInaccessible
        }

        let readValues = outcomes.values.compactMap { outcome -> Double? in
            guard case .success(let value) = outcome else { return nil }
            return value
        }

        if !failures.isEmpty, readValues.isEmpty {
            throw WalkingActivityReadError.allMetricsFailed(underlying: failures)
        }

        return lenientActivity(date: date, outcomes: outcomes)
    }

    /// Aggregates one background delivery's read, refusing to describe a day that nothing
    /// was read for.
    ///
    /// ``aggregate(date:outcomes:)`` already throws when reads failed. A delivery adds a case
    /// that must not become a payload either: every metric absent with nothing having failed.
    /// That is a day HealthKit has no samples for — which is exactly what a delivery arriving
    /// in the first seconds after midnight reads — and reporting it hands the caller a day of
    /// zeros indistinguishable from a real one.
    ///
    /// A day the caller asked for is different: an empty answer is the true answer and
    /// ``aggregate(date:outcomes:)`` still returns it. Nobody asked for a delivery, so a
    /// delivery with nothing to say says nothing.
    ///
    /// - Parameters:
    ///   - date: The day the metrics were read for.
    ///   - outcomes: The result of every attempted metric read.
    /// - Returns: The walking activity, or `nil` when no metric was read at all.
    /// - Throws: Whatever ``aggregate(date:outcomes:)`` throws.
    static func deliveryActivity(date: Date, outcomes: [WalkingMetric: Result<Double?, any Error>]) throws -> WalkingActivityData? {
        let activity = try aggregate(date: date, outcomes: outcomes)
        return carriesAMetric(activity) ? activity : nil
    }

    /// Whether a read produced any metric at all, as opposed to describing an absent day.
    ///
    /// - Parameter activity: The aggregated read.
    /// - Returns: `true` when at least one metric carries a value.
    static func carriesAMetric(_ activity: WalkingActivityData) -> Bool {
        activity.steps != nil
            || activity.activeCalories != nil
            || activity.distanceMeters != nil
            || activity.durationMinutes != nil
            || activity.averageHeartRate != nil
    }

    /// Aggregates outcomes without judging them, degrading every failed metric to `nil`.
    ///
    /// Used by the deprecated non-throwing read, which must keep returning whatever the
    /// day did produce rather than collapsing a partial read into an empty one.
    ///
    /// - Parameters:
    ///   - date: The day the metrics were read for.
    ///   - outcomes: The result of every attempted metric read.
    /// - Returns: The aggregated walking activity, with failed metrics absent.
    static func lenientActivity(date: Date, outcomes: [WalkingMetric: Result<Double?, any Error>]) -> WalkingActivityData {
        WalkingActivityData(
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
