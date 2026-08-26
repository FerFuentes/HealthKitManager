//
//  StepsDurationAggregator.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Computes total walking minutes from raw step-sample intervals, merging overlaps so
/// concurrent recordings of the same walk — an iPhone and a Watch both counting — are
/// not summed twice.
enum StepsDurationAggregator {

    /// Total minutes covered by the union of the given sample intervals.
    ///
    /// - Parameter intervals: The raw sample intervals for one day.
    /// - Returns: Minutes covered, rounded to two decimals, or `nil` when there are no samples.
    static func totalMinutes(coveredBy intervals: [DateInterval]) -> Double? {
        guard !intervals.isEmpty else { return nil }

        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in sorted {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        let totalSeconds = merged.reduce(0.0) { $0 + $1.duration }
        return (totalSeconds / 60.0).rounded(toDecimalPlaces: 2)
    }
}
