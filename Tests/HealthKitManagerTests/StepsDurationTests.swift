//
//  StepsDurationTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import Testing
@testable import HealthKitManager

/// Tests for step-duration aggregation: overlapping samples recorded by multiple
/// devices must be counted once, and a day without samples must not fabricate 0.0.
struct StepsDurationTests {

    private func interval(_ startMinutes: Double, _ endMinutes: Double) -> DateInterval {
        DateInterval(
            start: Date(timeIntervalSinceReferenceDate: startMinutes * 60),
            end: Date(timeIntervalSinceReferenceDate: endMinutes * 60)
        )
    }

    @Test func overlappingSamplesFromTwoDevicesCountOnce() {
        #expect(StepsDurationAggregator.totalMinutes(coveredBy: [interval(0, 10), interval(5, 15)]) == 15.0)
    }

    @Test func containedSampleAddsNothing() {
        #expect(StepsDurationAggregator.totalMinutes(coveredBy: [interval(0, 30), interval(10, 20)]) == 30.0)
    }

    @Test func disjointSamplesSumRegardlessOfOrder() {
        #expect(StepsDurationAggregator.totalMinutes(coveredBy: [interval(20, 30), interval(0, 10)]) == 20.0)
    }

    @Test func touchingSamplesMergeWithoutDoubleCountingTheBoundary() {
        #expect(StepsDurationAggregator.totalMinutes(coveredBy: [interval(0, 10), interval(10, 20)]) == 20.0)
    }

    @Test func emptyDayHasNoDuration() {
        #expect(StepsDurationAggregator.totalMinutes(coveredBy: []) == nil)
    }
}
