//
//  PartialMetricReadTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import Testing
import HealthKit
@testable import HealthKitManager

/// Tests the rule the sibling reads use to tell a partial read from a broken one.
struct PartialMetricReadTests {

    private struct MetricFailure: Error {}

    @Test func aReadThatProducedValuesIsReported() {
        #expect(PartialMetricRead.failureToSurface(readValues: [72, nil], failures: [MetricFailure()]) == nil)
    }

    @Test func aReadWithoutFailuresIsAlwaysReported() {
        #expect(PartialMetricRead.failureToSurface(readValues: [nil, nil], failures: []) == nil)
    }

    @Test func aReadWhereEverythingFailedOrCameBackEmptySurfacesItsFailure() {
        let failure = PartialMetricRead.failureToSurface(readValues: [nil], failures: [MetricFailure()])
        #expect(failure is MetricFailure)
    }

    @Test func aLockedDatabaseIsSurfacedEvenWhenOtherMetricsRead() {
        let failure = PartialMetricRead.failureToSurface(
            readValues: [72],
            failures: [HKError(.errorDatabaseInaccessible)]
        )
        #expect(failure?.isHealthKitDatabaseInaccessible == true)
    }
}
