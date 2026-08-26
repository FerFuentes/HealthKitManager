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
            dates: [Date()],
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
            dates: [Date()],
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

    @Test func deliveryCoversYesterdayThenToday() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let dates = HealthKitDeliveryProcessor.deliveryDates(endingAt: now, calendar: calendar)

        #expect(dates.count == 2)
        #expect(calendar.isDate(dates[0], inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now))
        #expect(dates[1] == now)
    }

    @Test func deliveryReportsEveryDayBeforeAcknowledging() async {
        let log = DeliveryLog()
        let yesterday = Date(timeIntervalSinceReferenceDate: 0)
        let today = Date(timeIntervalSinceReferenceDate: 86_400)

        await HealthKitDeliveryProcessor.processDelivery(
            dates: [yesterday, today],
            read: { date in
                WalkingActivityData(date: date, steps: date == today ? 200 : 100, activeCalories: nil, distanceMeters: nil, durationMinutes: nil, averageHeartRate: nil)
            },
            report: { outcome in
                if case .success(let data) = outcome, let steps = data?.steps {
                    log.append("report-\(Int(steps))")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["report-100", "report-200", "acknowledge"])
    }

    @Test func deliveryFailureOnOneDayStillReportsTheOtherAndAcknowledges() async {
        let log = DeliveryLog()
        let failingDay = Date(timeIntervalSinceReferenceDate: 0)
        let readableDay = Date(timeIntervalSinceReferenceDate: 86_400)

        await HealthKitDeliveryProcessor.processDelivery(
            dates: [failingDay, readableDay],
            read: { date in
                guard date == readableDay else { throw MetricFailure() }
                return WalkingActivityData(date: date, steps: 300, activeCalories: nil, distanceMeters: nil, durationMinutes: nil, averageHeartRate: nil)
            },
            report: { outcome in
                switch outcome {
                case .success:
                    log.append("report-success")
                case .failure:
                    log.append("report-failure")
                }
            },
            acknowledge: { log.append("acknowledge") }
        )

        #expect(log.all == ["report-success", "report-failure", "acknowledge"])
    }

    @Test func deliveryReportsAtMostOneFailureRegardlessOfHowManyDaysFailed() async {
        let log = DeliveryLog()

        await HealthKitDeliveryProcessor.processDelivery(
            dates: [Date(timeIntervalSinceReferenceDate: 0), Date(timeIntervalSinceReferenceDate: 86_400)],
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
}
