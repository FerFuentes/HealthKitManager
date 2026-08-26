//
//  HealthKitDeliveryProcessor.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Bridges one HealthKit background delivery to async processing while honoring Apple's
/// acknowledgement contract: the delivery is acknowledged on every path, and only after
/// processing finished and the caller was notified. iOS permanently stops background
/// delivery for a sample type after three unacknowledged deliveries.
///
/// - Note: Processing runs in a detached task, so the system can suspend the app between
///   the read and the acknowledgement — a delivery interrupted that way is retried by
///   HealthKit rather than lost. Holding a background assertion across the read would
///   require blocking a thread for the whole async read, which trades a rare retry for a
///   guaranteed priority inversion; the retry is the better deal.
enum HealthKitDeliveryProcessor {

    /// Processes one background delivery day by day and acknowledges it exactly once, afterwards.
    ///
    /// Each day that reads cleanly is reported on its own. Days that fail collapse into a
    /// single failure for the whole delivery, so one broken read cannot flood the subscriber
    /// with a callback per day.
    ///
    /// - Parameters:
    ///   - dates: The days to re-read for this delivery, reported in order.
    ///   - read: Produces the activity for one day of the delivery being processed.
    ///   - report: Receives each day's outcome, before the delivery is acknowledged.
    ///   - acknowledge: HealthKit's completion handler for this specific delivery.
    static func processDelivery<Activity: Sendable>(
        dates: [Date],
        read: @Sendable (Date) async throws -> Activity,
        report: @Sendable (Result<Activity?, any Error>) -> Void,
        acknowledge: @Sendable () -> Void
    ) async {
        var firstFailure: (any Error)?

        for date in dates {
            do {
                let activity = try await read(date)
                report(.success(activity))
            } catch {
                firstFailure = firstFailure ?? error
            }
        }

        if let firstFailure {
            report(.failure(firstFailure))
        }

        acknowledge()
    }

    /// The days one background delivery must cover: the previous day first, then the
    /// current one, so samples that sync in shortly after midnight still update the
    /// tail of the day they belong to.
    ///
    /// - Parameters:
    ///   - now: The moment the delivery arrived.
    ///   - calendar: The calendar used to step back one day.
    /// - Returns: The dates to read, oldest first.
    static func deliveryDates(endingAt now: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> [Date] {
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: now) else {
            return [now]
        }
        return [previousDay, now]
    }
}
