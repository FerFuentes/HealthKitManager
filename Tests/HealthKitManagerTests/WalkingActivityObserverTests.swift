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

/// Tests for the walking activity observer's restart policy.
struct WalkingActivityObserverTests {

    @Test func restartBacksOffExponentially() {
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 1) == .seconds(1))
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 2) == .seconds(2))
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 3) == .seconds(4))
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 4) == .seconds(8))
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 5) == .seconds(16))
    }

    @Test func restartGivesUpOnceThePolicyIsExhausted() {
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 6) == nil)
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 100) == nil)
    }

    @Test func restartRequiresAtLeastOneFailure() {
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: 0) == nil)
        #expect(WalkingActivityObserverRetryPolicy.restartDelay(afterConsecutiveFailures: -3) == nil)
    }

    @Test func observerWatchesEveryWalkingDeliveryType() {
        let manager = HealthKitManager.shared
        let observed = Set(manager.walkingActivityObserverDescriptors().map(\.sampleType))
        let enabled = Set(manager.forWalkingActivityQuantityType.map { $0 as HKSampleType })

        #expect(observed == enabled)
    }
}
