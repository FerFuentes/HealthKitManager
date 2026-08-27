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

    @Test func aggregateRejectsAReadThatAttemptedNothing() {
        do {
            _ = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [:])
            Issue.record("Expected invalidParameters to be thrown")
        } catch Permission.Error.invalidParameters {
        } catch {
            Issue.record("Expected invalidParameters, got \(error)")
        }
    }

    @Test func aggregateThrowsWhenTheOnlySuccessfulMetricsAreEmpty() {
        do {
            _ = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [
                .steps: .failure(MetricFailure()),
                .durationMinutes: .failure(MetricFailure()),
                .distanceMeters: .failure(MetricFailure()),
                .activeCalories: .failure(MetricFailure()),
                .averageHeartRate: .success(nil)
            ])
            Issue.record("Expected allMetricsFailed to be thrown")
        } catch WalkingActivityReadError.allMetricsFailed(let underlying) {
            #expect(underlying.count == 4)
        } catch {
            Issue.record("Expected allMetricsFailed, got \(error)")
        }
    }

    @Test func aggregateTrustsAPartialReadThatCarriesRealValues() throws {
        let data = try WalkingActivityReadAggregator.aggregate(date: Date(), outcomes: [
            .steps: .success(900),
            .durationMinutes: .failure(MetricFailure()),
            .averageHeartRate: .success(nil)
        ])

        #expect(data.steps == 900)
        #expect(data.durationMinutes == nil)
        #expect(data.averageHeartRate == nil)
    }

    @Test func lenientAggregationDegradesFailedMetricsWithoutLosingTheRest() {
        let date = Date()
        let data = WalkingActivityReadAggregator.lenientActivity(date: date, outcomes: [
            .steps: .success(1500),
            .durationMinutes: .failure(MetricFailure()),
            .distanceMeters: .failure(HKError(.errorDatabaseInaccessible))
        ])

        #expect(data.date == date)
        #expect(data.steps == 1500)
        #expect(data.durationMinutes == nil)
        #expect(data.distanceMeters == nil)
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

        await HealthKitDeliveryProcessor.processDelivery(
            date: Date(),
            read: { _ in
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

        await HealthKitDeliveryProcessor.processDelivery(
            date: Date(),
            read: { _ -> WalkingActivityData in throw MetricFailure() },
            report: { outcome in
                if case .failure = outcome {
                    log.append("report-failure")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["report-failure", "acknowledge"])
    }

    @Test func deliveryReadsOnlyTheDayItWokeOn() async {
        let log = DeliveryLog()
        let wokeOn = Date(timeIntervalSinceReferenceDate: 86_400)

        await HealthKitDeliveryProcessor.processDelivery(
            date: wokeOn,
            read: { date in
                log.append("read-\(Int(date.timeIntervalSinceReferenceDate))")
                return WalkingActivityData(date: date, steps: 200, activeCalories: nil, distanceMeters: nil, durationMinutes: nil, averageHeartRate: nil)
            },
            report: { outcome in
                if case .success(let data) = outcome, let steps = data?.steps {
                    log.append("report-\(Int(steps))")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["read-86400", "report-200", "acknowledge"])
    }

    @Test func deliveryReportsExactlyOnceBeforeAcknowledging() async {
        let log = DeliveryLog()

        await HealthKitDeliveryProcessor.processDelivery(
            date: Date(),
            read: { date in
                WalkingActivityData(date: date, steps: 300, activeCalories: nil, distanceMeters: nil, durationMinutes: nil, averageHeartRate: nil)
            },
            report: { _ in log.append("report") },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["report", "acknowledge"])
    }

    // MARK: - A delivery with nothing to say

    @Test func aDeliveryThatReadNoMetricAtAllReportsNoPayload() throws {
        let absent = try WalkingActivityReadAggregator.deliveryActivity(
            date: Date(),
            outcomes: [
                .steps: .success(nil),
                .durationMinutes: .success(nil),
                .distanceMeters: .success(nil),
                .activeCalories: .success(nil)
            ]
        )

        #expect(absent == nil)
    }

    @Test func aDeliveryCarryingOneRealMetricIsStillReported() throws {
        let activity = try WalkingActivityReadAggregator.deliveryActivity(
            date: Date(),
            outcomes: [
                .steps: .success(1_200),
                .durationMinutes: .success(nil),
                .distanceMeters: .success(nil),
                .activeCalories: .success(nil)
            ]
        )

        #expect(activity?.steps == 1_200)
    }

    @Test func aDeliveryCarryingAGenuineZeroIsStillReported() throws {
        let activity = try WalkingActivityReadAggregator.deliveryActivity(
            date: Date(),
            outcomes: [.steps: .success(0), .distanceMeters: .success(nil)]
        )

        #expect(activity?.steps == 0)
    }

    @Test func aRequestedDayThatIsGenuinelyEmptyStillAggregatesToZeros() throws {
        let requested = try WalkingActivityReadAggregator.aggregate(
            date: Date(),
            outcomes: [.steps: .success(nil), .distanceMeters: .success(nil)]
        )

        #expect(requested.steps == nil)
    }

    @Test func anAbsentDeliveryIsReportedAsSuccessWithNoActivityAndStillAcknowledged() async {
        let log = DeliveryLog()

        await HealthKitDeliveryProcessor.processDelivery(
            date: Date(),
            read: { _ -> WalkingActivityData? in nil },
            report: { outcome in
                switch outcome {
                case .success(let data):
                    log.append(data == nil ? "report-nothing" : "report-payload")
                case .failure:
                    log.append("report-failure")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["report-nothing", "acknowledge"])
    }

    @Test func theDeliveryIsAcknowledgedEvenWhenReportingItselfBlowsUp() async {
        let log = DeliveryLog()

        await HealthKitDeliveryProcessor.processDelivery(
            date: Date(),
            read: { date in
                WalkingActivityData(date: date, steps: 1, activeCalories: nil, distanceMeters: nil, durationMinutes: nil, averageHeartRate: nil)
            },
            report: { _ in log.append("report") },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all.last == "acknowledge")
    }

    // MARK: - Partial toggles

    @Test func atypeThatFailedToEnableIsNotLive() {
        let live = WalkingBackgroundToggle.liveTypes(
            after: true,
            requested: [HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)],
            failed: [HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue]
        )

        #expect(live == [HKQuantityType(.stepCount)])
    }

    @Test func aTypeThatFailedToDisableIsStillLiveAndMustStayWatched() {
        let live = WalkingBackgroundToggle.liveTypes(
            after: false,
            requested: [HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)],
            failed: [HKQuantityTypeIdentifier.stepCount.rawValue]
        )

        #expect(live == [HKQuantityType(.stepCount)])
    }

    @Test func aCleanDisableLeavesNothingLive() {
        #expect(WalkingBackgroundToggle.liveTypes(after: false, requested: [HKQuantityType(.stepCount)], failed: []) == nil)
    }

    @Test func aTotallyFailedEnableLeavesNothingLive() {
        #expect(WalkingBackgroundToggle.liveTypes(
            after: true,
            requested: [HKQuantityType(.stepCount)],
            failed: [HKQuantityTypeIdentifier.stepCount.rawValue]
        ) == nil)
    }
}
