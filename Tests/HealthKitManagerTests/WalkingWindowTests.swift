//
//  WalkingWindowTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 01/09/26.
//

import Foundation
import Testing
import HealthKit
@testable import HealthKitManager

/// The window read answers a whole sweep with one query per metric instead of one per
/// day. These cover the arithmetic that decides which day an answer belongs to — the
/// only place a range read can change a number the per-day read already produced.
struct WalkingWindowTests {

    private static func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private static func date(_ iso: String, _ timeZone: String = "America/Los_Angeles") -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZone)!
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso)!
    }

    // MARK: - The days a window covers

    @Test func requestedDaysCollapseToOrderedStartsOfDay() {
        let calendar = Self.calendar("America/Los_Angeles")
        let days = WalkingWindow.days(
            for: [
                Self.date("2026-08-12 23:59"),
                Self.date("2026-08-10 06:30"),
                Self.date("2026-08-12 00:01"),
                Self.date("2026-08-10 18:00")
            ],
            calendar: calendar
        )

        #expect(days == [Self.date("2026-08-10 00:00"), Self.date("2026-08-12 00:00")])
    }

    @Test func aSparseRequestKeepsOnlyTheDaysAsked() {
        let calendar = Self.calendar("America/Los_Angeles")
        let days = WalkingWindow.days(
            for: [Self.date("2026-08-01 09:00"), Self.date("2026-08-30 09:00")],
            calendar: calendar
        )

        #expect(days.count == 2)
        #expect(days.first == Self.date("2026-08-01 00:00"))
        #expect(days.last == Self.date("2026-08-30 00:00"))
    }

    // MARK: - Daylight saving

    @Test func aDayThatGainsAnHourIsStillOneDay() {
        let calendar = Self.calendar("America/Los_Angeles")
        let fallBack = Self.date("2026-11-01 00:00")

        let end = WalkingWindow.end(of: fallBack, calendar: calendar)

        #expect(end == Self.date("2026-11-02 00:00"))
        #expect(end.timeIntervalSince(fallBack) == 90_000)
    }

    @Test func aDayThatLosesAnHourIsStillOneDay() {
        let calendar = Self.calendar("America/Los_Angeles")
        let springForward = Self.date("2026-03-08 00:00")

        let end = WalkingWindow.end(of: springForward, calendar: calendar)

        #expect(end == Self.date("2026-03-09 00:00"))
        #expect(end.timeIntervalSince(springForward) == 82_800)
    }

    @Test func everyDayOfAWindowCrossingTheTransitionStartsAtItsOwnMidnight() {
        let calendar = Self.calendar("America/Los_Angeles")
        let days = WalkingWindow.days(
            for: [
                Self.date("2026-10-31 12:00"),
                Self.date("2026-11-01 12:00"),
                Self.date("2026-11-02 12:00")
            ],
            calendar: calendar
        )

        #expect(days == [
            Self.date("2026-10-31 00:00"),
            Self.date("2026-11-01 00:00"),
            Self.date("2026-11-02 00:00")
        ])
    }

    // MARK: - Which day a sample belongs to

    @Test func aWalkCrossingMidnightBelongsToBothDays() {
        let calendar = Self.calendar("America/Los_Angeles")
        let crossing = DateInterval(
            start: Self.date("2026-08-10 23:40"),
            end: Self.date("2026-08-11 00:20")
        )

        let firstDay = WalkingWindow.intervals(
            from: [crossing], overlapping: Self.date("2026-08-10 00:00"), calendar: calendar
        )
        let secondDay = WalkingWindow.intervals(
            from: [crossing], overlapping: Self.date("2026-08-11 00:00"), calendar: calendar
        )

        #expect(firstDay == [crossing])
        #expect(secondDay == [crossing])
    }

    @Test func aCrossingWalkIsHandedOverUnclipped() {
        let calendar = Self.calendar("America/Los_Angeles")
        let crossing = DateInterval(
            start: Self.date("2026-08-10 23:40"),
            end: Self.date("2026-08-11 00:20")
        )

        let secondDay = WalkingWindow.intervals(
            from: [crossing], overlapping: Self.date("2026-08-11 00:00"), calendar: calendar
        )

        #expect(StepsDurationAggregator.totalMinutes(coveredBy: secondDay) == 40)
    }

    @Test func aWalkEndingExactlyAtMidnightBelongsOnlyToTheDayItRanIn() {
        let calendar = Self.calendar("America/Los_Angeles")
        let upToMidnight = DateInterval(
            start: Self.date("2026-08-10 23:30"),
            end: Self.date("2026-08-11 00:00")
        )

        let nextDay = WalkingWindow.intervals(
            from: [upToMidnight], overlapping: Self.date("2026-08-11 00:00"), calendar: calendar
        )

        #expect(nextDay.isEmpty)
    }

    @Test func aDayWithNoOverlappingSamplesReportsNoMinutes() {
        let calendar = Self.calendar("America/Los_Angeles")
        let elsewhere = DateInterval(
            start: Self.date("2026-08-14 09:00"),
            end: Self.date("2026-08-14 09:30")
        )

        let quietDay = WalkingWindow.intervals(
            from: [elsewhere], overlapping: Self.date("2026-08-10 00:00"), calendar: calendar
        )

        #expect(StepsDurationAggregator.totalMinutes(coveredBy: quietDay) == nil)
    }

    @Test func overlappingRecordingsOfOneWalkStillCountOnce() {
        let calendar = Self.calendar("America/Los_Angeles")
        let phone = DateInterval(start: Self.date("2026-08-10 08:00"), end: Self.date("2026-08-10 08:30"))
        let watch = DateInterval(start: Self.date("2026-08-10 08:10"), end: Self.date("2026-08-10 08:40"))

        let day = WalkingWindow.intervals(
            from: [phone, watch], overlapping: Self.date("2026-08-10 00:00"), calendar: calendar
        )

        #expect(StepsDurationAggregator.totalMinutes(coveredBy: day) == 40)
    }

    // MARK: - Which metrics a sweep attempts

    @Test func stepsAndDurationBothRideOnTheStepCountType() {
        let types: Set<HKSampleType> = [HKQuantityType(.stepCount)]

        #expect(WalkingMetric.steps.isRequested(in: types))
        #expect(WalkingMetric.durationMinutes.isRequested(in: types))
        #expect(!WalkingMetric.distanceMeters.isRequested(in: types))
        #expect(!WalkingMetric.activeCalories.isRequested(in: types))
        #expect(!WalkingMetric.averageHeartRate.isRequested(in: types))
    }

    @Test func theWalkingPayloadNamesEveryMetricAReadAttempts() {
        #expect(Set(WalkingMetric.walkingPayload) == Set([
            .steps, .durationMinutes, .distanceMeters, .activeCalories, .averageHeartRate
        ]))
    }
}
