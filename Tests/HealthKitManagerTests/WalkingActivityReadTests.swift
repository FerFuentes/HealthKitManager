//
//  WalkingActivityReadTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import Testing
import HealthKit
@testable import HealthKitManager

/// Tests for the honest aggregation of walking metric reads and for the
/// background-delivery acknowledgement contract.
struct WalkingActivityReadTests {

    private struct MetricFailure: Error {}

    /// Records delivery events across `@Sendable` closures to assert their ordering.
    private final class DeliveryLog: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [String] = []

        func append(_ entry: String) {
            lock.lock()
            entries.append(entry)
            lock.unlock()
        }

        var all: [String] {
            lock.lock()
            defer { lock.unlock() }
            return entries
        }
    }

    // MARK: - Aggregation

    @Test func aggregateKeepsSuccessfulValues() throws {
        let date = Date()
        let data = try WalkingActivityReadAggregator.aggregate(date: date, outcomes: [
            .steps: .success(1200),
            .durationMinutes: .success(34.5),
            .distanceMeters: .success(nil),
            .activeCalories: .success(210),
            .averageHeartRate: .success(nil)
        ])

        #expect(data.date == date)
        #expect(data.steps == 1200)
        #expect(data.durationMinutes == 34.5)
        #expect(data.distanceMeters == nil)
        #expect(data.activeCalories == 210)
        #expect(data.averageHeartRate == nil)
    }

    @Test func aggregateNilsMetricsThatWereNotAttempted() throws {
        let data = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [
            .steps: .success(800)
        ])

        #expect(data.steps == 800)
        #expect(data.distanceMeters == nil)
        #expect(data.averageHeartRate == nil)
    }

    @Test func aggregateKeepsPartialDataWhenOneMetricFails() throws {
        let data = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [
            .steps: .success(800),
            .averageHeartRate: .failure(MetricFailure())
        ])

        #expect(data.steps == 800)
        #expect(data.averageHeartRate == nil)
    }

    @Test func aggregateReturnsEmptyDayWhenNothingWasAttempted() throws {
        let data = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [:])

        #expect(data.steps == nil)
        #expect(data.durationMinutes == nil)
    }

    @Test func aggregateThrowsWhenDatabaseIsLockedEvenWithPartialData() {
        do {
            _ = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [
                .steps: .success(800),
                .averageHeartRate: .failure(HKError(.errorDatabaseInaccessible))
            ])
            Issue.record("Expected databaseInaccessible to be thrown")
        } catch WalkingActivityReadError.databaseInaccessible {
        } catch {
            Issue.record("Expected databaseInaccessible, got \(error)")
        }
    }

    @Test func aggregateThrowsWhenEveryMetricFails() {
        do {
            _ = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [
                .steps: .failure(MetricFailure()),
                .durationMinutes: .failure(MetricFailure())
            ])
            Issue.record("Expected allMetricsFailed to be thrown")
        } catch WalkingActivityReadError.allMetricsFailed(let underlying) {
            #expect(underlying.count == 2)
        } catch {
            Issue.record("Expected allMetricsFailed, got \(error)")
        }
    }

    // MARK: - Locked-database detection

    @Test func databaseInaccessibleDetectionMatchesOnlyTheLockedCode() {
        #expect(HKError(.errorDatabaseInaccessible).isHealthKitDatabaseInaccessible)
        #expect(NSError(domain: HKErrorDomain, code: HKError.Code.errorDatabaseInaccessible.rawValue).isHealthKitDatabaseInaccessible)
        #expect(!HKError(.errorHealthDataUnavailable).isHealthKitDatabaseInaccessible)
        #expect(!MetricFailure().isHealthKitDatabaseInaccessible)
    }

    // MARK: - Delivery acknowledgement

    @Test func deliveryIsAcknowledgedAfterSuccessfulProcessing() async {
        let log = DeliveryLog()
        let activity = WalkingActivityData(date: Date(), steps: 100, activeCalories: nil, distanceMeters: nil, durationMinutes: nil, averageHeartRate: nil)

        await WalkingActivityDeliveryHandler.processDelivery(
            read: {
                log.append("read")
                return activity
            },
            report: { outcome in
                if case .success(let data) = outcome, data?.steps == 100 {
                    log.append("report-success")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["read", "report-success", "acknowledge"])
    }

    @Test func deliveryIsAcknowledgedAfterFailedProcessing() async {
        let log = DeliveryLog()

        await WalkingActivityDeliveryHandler.processDelivery(
            read: { throw MetricFailure() },
            report: { outcome in
                if case .failure = outcome {
                    log.append("report-failure")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["report-failure", "acknowledge"])
    }
}
