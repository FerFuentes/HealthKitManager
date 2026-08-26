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

/// Tests for which walking types the observer registers.
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
        #expect(Set(manager.walkingActivityObserverDescriptors().map(\.sampleType)) == Set(manager.forWalkingActivityQuantityType.map { $0 as HKSampleType }))

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)])
        let observed = Set(manager.walkingActivityObserverDescriptors().map(\.sampleType))

        #expect(observed == Set([HKQuantityType(.stepCount) as HKSampleType, HKQuantityType(.distanceWalkingRunning) as HKSampleType]))
        #expect(!observed.contains(HKQuantityType(.heartRate) as HKSampleType))
    }
}
