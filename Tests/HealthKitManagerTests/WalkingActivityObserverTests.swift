//
//  WalkingActivityObserverTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import Testing
import HealthKit
@testable import HealthKitManager

/// Tests for which walking types the observer registers and which it reads.
///
/// Serialized: these drive `HealthKitManager.shared`'s remembered background types, which is
/// process-wide state, so running them beside each other makes both flaky.
@Suite(.serialized)
struct WalkingActivityObserverTests {

    @Test func restartBacksOffExponentiallyThenGivesUp() {
        #expect(HealthKitObservationRetryPolicy.restartDelay(afterConsecutiveFailures: 1) == .seconds(1))
        #expect(HealthKitObservationRetryPolicy.restartDelay(afterConsecutiveFailures: 5) == .seconds(16))
        #expect(HealthKitObservationRetryPolicy.restartDelay(afterConsecutiveFailures: 6) == nil)
        #expect(HealthKitObservationRetryPolicy.restartDelay(afterConsecutiveFailures: 0) == nil)
    }

    @Test func observerWatchesExactlyTheTypesEnabledForDelivery() {
        let manager = HealthKitManager.shared
        defer { manager.rememberWalkingActivityBackgroundTypes(nil) }

        manager.rememberWalkingActivityBackgroundTypes(nil)
        #expect(Set(manager.walkingActivityObserverDescriptors().map(\.sampleType)) == Set(HealthKitManager.forWalkingActivityQuantityType.map { $0 as HKSampleType }))

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)])
        let observed = Set(manager.walkingActivityObserverDescriptors().map(\.sampleType))

        #expect(observed == Set([HKQuantityType(.stepCount) as HKSampleType, HKQuantityType(.distanceWalkingRunning) as HKSampleType]))
        #expect(!observed.contains(HKQuantityType(.heartRate) as HKSampleType))
    }

    /// Pins the composition of the delivery payload constant. Which set the delivery read
    /// actually passes is not covered here — that line only runs against a live health store —
    /// so it is held structurally instead: `readWalkingActivityDelivery` takes no sample-type
    /// parameter, leaving nothing for a caller to pass it.
    @Test func theDeliveryPayloadIsTheWalkingTypesWithoutHeartRate() {
        #expect(HealthKitManager.walkingActivityDeliverySampleTypes
            == Set(HealthKitManager.forWalkingActivityQuantityType.subtracting([HKQuantityType(.heartRate)]).map { $0 as HKSampleType }))
        #expect(!HealthKitManager.walkingActivityDeliverySampleTypes.contains(HKQuantityType(.heartRate) as HKSampleType))
    }
}
