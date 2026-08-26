//
//  BackgroundDeliveryTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import Testing
import HealthKit
@testable import HealthKitManager

/// Tests for the background-delivery authorization gate, which must never
/// present the permission sheet from app-startup paths.
struct BackgroundDeliveryTests {

    private struct MetricFailure: Error {}

    @Test func establishedAuthorizationPassesWhenRequestIsUnnecessary() throws {
        try HealthKitManager.requireEstablishedAuthorization(.unnecessary)
    }

    @Test func establishedAuthorizationRejectsAnUnrequestedStatus() {
        do {
            try HealthKitManager.requireEstablishedAuthorization(.shouldRequest)
            Issue.record("Expected needToRequestPermission to be thrown")
        } catch Permission.Error.needToRequestPermission {
        } catch {
            Issue.record("Expected needToRequestPermission, got \(error)")
        }
    }

    @Test func toggleFailuresNameEveryTypeThatKeptItsPreviousState() {
        let failure = BackgroundDeliveryError(failures: [
            (HKQuantityType(.stepCount), MetricFailure()),
            (HKQuantityType(.heartRate), MetricFailure())
        ])

        #expect(failure?.failedTypeIdentifiers.contains(HKQuantityTypeIdentifier.stepCount.rawValue) == true)
        #expect(failure?.failedTypeIdentifiers.contains(HKQuantityTypeIdentifier.heartRate.rawValue) == true)
        #expect(failure?.underlying.count == 2)
    }

    @Test func aFullySuccessfulToggleIsNotAnError() {
        #expect(BackgroundDeliveryError(failures: []) == nil)
    }

    @Test func establishedAuthorizationRejectsAnUnknownStatus() {
        do {
            try HealthKitManager.requireEstablishedAuthorization(.unknown)
            Issue.record("Expected unavailable to be thrown")
        } catch Permission.Error.unavailable {
        } catch {
            Issue.record("Expected unavailable, got \(error)")
        }
    }
}
