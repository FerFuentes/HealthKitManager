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
enum HealthKitDeliveryProcessor {

    /// Processes one background delivery day by day and acknowledges it exactly once, afterwards.
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
        for date in dates {
            do {
                let activity = try await read(date)
                report(.success(activity))
            } catch {
                report(.failure(error))
            }
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
