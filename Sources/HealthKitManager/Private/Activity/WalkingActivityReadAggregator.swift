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

    /// Aggregates one background delivery's read, refusing to describe a day whose steps
    /// could not be read.
    ///
    /// Steps are what a walking day is promoted on, so a delivery without them has nothing to
    /// say: reporting one hands the caller a day whose steps read as zero, indistinguishable
    /// from a real day of not moving. That is what a delivery landing in the first seconds
    /// after midnight reads, and what a device that has produced nothing yet reads.
    ///
    /// The rules ``aggregate(date:outcomes:)`` already applies come first, so a locked database
    /// still surfaces as a failure rather than being swallowed as silence.
    ///
    /// A day the caller asked for is different: an empty answer is the true answer to a
    /// question the server asked, and ``aggregate(date:outcomes:)`` still returns it. Nobody
    /// asked for a delivery, so a delivery with nothing to promote says nothing.
    ///
    /// Whatever else the read did or did not find travels as it is. An absent distance or
    /// calorie count is left absent rather than withheld: suppressing a day because one metric
    /// is missing would lose the steps that are the point of the delivery, and a metric the
    /// member has switched off in Health is absent on every delivery, forever.
    ///
    /// Steps absent and steps *unreadable* are not the same answer, and only the aggregated
    /// value cannot tell them apart — both arrive as `nil`. The outcome is what decides: a
    /// steps read that threw is reported as the failure it was, rather than passed off as a
    /// day nobody walked, which is the confusion ``WalkingActivityData`` exists to prevent.
    ///
    /// - Note: A member whose device records distance or calories but no steps — a wheelchair
    ///   user, or a treadmill source that writes distance only — has nothing posted by a
    ///   delivery. That is deliberate, not an oversight: steps are the unit the day is
    ///   promoted on, and there is nothing to promote without them.
    ///
    /// - Parameters:
    ///   - date: The day the metrics were read for.
    ///   - outcomes: The result of every attempted metric read.
    /// - Returns: The walking activity, or `nil` when the day genuinely has no steps.
    /// - Throws: Whatever ``aggregate(date:outcomes:)`` throws, or the steps read's own failure
    ///   when steps could not be read.
    static func deliveryActivity(date: Date, outcomes: [WalkingMetric: Result<Double?, any Error>]) throws -> WalkingActivityData? {
        let activity = try aggregate(date: date, outcomes: outcomes)

        if case .failure(let stepsFailure)? = outcomes[.steps] {
            throw stepsFailure
        }

        return activity.steps == nil ? nil : activity
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
