//
//  StoreLockTests.swift
//  HealthKitManager
//

import Foundation
import Testing
import HealthKit
@testable import HealthKitManager

/// A locked store is answered without a query, the way HealthKit itself would answer it.
///
/// The window read asks for authorization before it checks the lock, so a missing permission
/// is never reported as a locked phone; that order needs a granted store, which the simulator
/// does not have, so the window's branch is covered through the helper both branches share.
struct StoreLockTests {

    private let types: Set<HKSampleType> = [HKQuantityType(.stepCount), HKQuantityType(.heartRate)]

    private func refusedForLock<Value>(_ outcomes: [WalkingMetric: Result<Value, any Error>]) -> Bool {
        outcomes.values.allSatisfy {
            if case .failure(let error) = $0 { return error.isHealthKitDatabaseInaccessible }
            return false
        }
    }

    @Test func aLockedStoreRefusesEveryRequestedMetricOfADay() async {
        let outcomes = await HealthKitManager.shared.walkingActivityMetricOutcomes(
            date: Date(), sampleTypes: types, isStoreLocked: { true }
        )

        #expect(Set(outcomes.keys) == [.steps, .durationMinutes, .averageHeartRate])
        #expect(refusedForLock(outcomes))
    }

    @Test func everyRequestedMetricIsFailedWithTheGivenError() {
        let outcomes: [WalkingMetric: Result<Double?, any Error>] = WalkingMetric.failingEveryRequested(
            in: types, with: HKError(.errorDatabaseInaccessible)
        )

        #expect(Set(outcomes.keys) == [.steps, .durationMinutes, .averageHeartRate])
        #expect(refusedForLock(outcomes))
    }

    @Test func aLockedDayReadsAsTheLockedStoreError() async {
        let outcomes = await HealthKitManager.shared.walkingActivityMetricOutcomes(
            date: Date(), sampleTypes: types, isStoreLocked: { true }
        )

        do {
            _ = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: outcomes)
            Issue.record("A locked day produced activity")
        } catch WalkingActivityReadError.databaseInaccessible {
        } catch {
            Issue.record("A locked day failed as \(error) instead of databaseInaccessible")
        }
    }
}
