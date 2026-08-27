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
        #expect(Set(manager.walkingActivityObserverDescriptors().map(\.sampleType)) == Set(manager.forWalkingActivityQuantityType.map { $0 as HKSampleType }))

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)])
        let observed = Set(manager.walkingActivityObserverDescriptors().map(\.sampleType))

        #expect(observed == Set([HKQuantityType(.stepCount) as HKSampleType, HKQuantityType(.distanceWalkingRunning) as HKSampleType]))
        #expect(!observed.contains(HKQuantityType(.heartRate) as HKSampleType))
    }

    @Test func theDeliveryReadIsTheWalkingPayloadAndNeverTheSetThatWokeIt() {
        let manager = HealthKitManager.shared
        defer { manager.rememberWalkingActivityBackgroundTypes(nil) }

        let payload = Set([
            HKQuantityType(.stepCount) as HKSampleType,
            HKQuantityType(.distanceWalkingRunning) as HKSampleType,
            HKQuantityType(.activeEnergyBurned) as HKSampleType
        ])

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.stepCount)])
        #expect(manager.walkingActivityDeliverySampleTypes == payload)
        #expect(Set(manager.walkingActivityObserverDescriptors().map(\.sampleType)) != manager.walkingActivityDeliverySampleTypes)

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.heartRate)])
        #expect(manager.walkingActivityDeliverySampleTypes == payload)
    }

    @Test func theDeliveryReadStaysDerivedFromTheWalkingTypesMinusHeartRate() {
        let manager = HealthKitManager.shared

        #expect(manager.walkingActivityDeliverySampleTypes
            == Set(manager.forWalkingActivityQuantityType.subtracting([HKQuantityType(.heartRate)]).map { $0 as HKSampleType }))
        #expect(!manager.walkingActivityDeliverySampleTypes.contains(HKQuantityType(.heartRate) as HKSampleType))
    }

    @Test func aChangedEnabledSetIsReflectedInTheDescriptorsTheObserverWouldRegister() {
        let manager = HealthKitManager.shared
        defer { manager.rememberWalkingActivityBackgroundTypes(nil) }

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.stepCount)])
        #expect(Set(manager.walkingActivityObserverDescriptors().map(\.sampleType)) == [HKQuantityType(.stepCount) as HKSampleType])

        manager.rememberWalkingActivityBackgroundTypes([HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned)])
        #expect(Set(manager.walkingActivityObserverDescriptors().map(\.sampleType))
            == Set([HKQuantityType(.stepCount) as HKSampleType, HKQuantityType(.activeEnergyBurned) as HKSampleType]))
    }
}
