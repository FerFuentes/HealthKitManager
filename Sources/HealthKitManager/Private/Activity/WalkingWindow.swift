//
//  WalkingWindow.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 01/09/26.
//

import Foundation

/// The date arithmetic a window read depends on, kept apart from HealthKit so the
/// rules that decide which day a sample belongs to can be checked without a store.
///
/// Every member takes its calendar, defaulting to the one the per-day read uses, so a
/// test can pose a window in a time zone that changes offset mid-window.
enum WalkingWindow {

    /// The calendar the per-day read has always used.
    static var `default`: Calendar { Calendar(identifier: .gregorian) }

    /// The requested dates as starts of day, deduplicated and ordered.
    ///
    /// Callers hand over whatever the server asked for, which can repeat a day or arrive
    /// unsorted; the window is built from the earliest and latest of these, so both have
    /// to be settled before a query is shaped.
    static func days(for dates: [Date], calendar: Calendar = WalkingWindow.default) -> [Date] {
        Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
    }

    /// Where a day ends, which is the start of the next one.
    ///
    /// Adding a day rather than twenty-four hours is what keeps a day that gains or loses
    /// an hour to daylight saving still exactly one day long.
    static func end(of day: Date, calendar: Calendar = WalkingWindow.default) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
    }

    /// The intervals that belong to a day, by the same rule the per-day read uses.
    ///
    /// HealthKit's day predicate keeps any sample *overlapping* the day rather than only
    /// those starting inside it, so a walk crossing midnight counts on both days it
    /// touches. Bucketing by start date would silently drop it from the second day and
    /// shorten that day's minutes, so overlap is the test and the interval is left
    /// unclipped — the aggregator receives exactly what the per-day query handed it.
    static func intervals(
        from intervals: [DateInterval],
        overlapping day: Date,
        calendar: Calendar = WalkingWindow.default
    ) -> [DateInterval] {
        let dayEnd = end(of: day, calendar: calendar)
        return intervals.filter { $0.start < dayEnd && $0.end > day }
    }
}
