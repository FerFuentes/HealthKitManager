//
//  StepsDuration.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 23/01/25.
//
import HealthKit

internal extension HealthKitManager {

    /// Total minutes covered by the day's step samples with overlapping device
    /// recordings merged, or `nil` when the day has no samples at all.
    ///
    /// - Parameter date: The day to query.
    /// - Returns: Active walking minutes, or `nil` for a sample-less day.
    /// - Throws: A `Permission.Error` or `HKError` when the samples cannot be read.
    func getTotalDurationInMinutes(date: Date) async throws -> Double? {
        let type = HKQuantityType(.stepCount)
        _ = try checkAuthorizationStatus(for: type)

        let stepSamples = try await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: getPredicate(date: date))],
            sortDescriptors: []
        ).result(for: healthStore)

        return StepsDurationAggregator.totalMinutes(
            coveredBy: stepSamples.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        )
    }
}
