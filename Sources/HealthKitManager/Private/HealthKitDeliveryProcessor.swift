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

    /// Reads the day a delivery woke on, reports it once, and acknowledges the delivery
    /// afterwards — on success and on failure alike.
    ///
    /// One delivery is one day. An observer keeps the running day current, which is what
    /// an observer is for; recovering an earlier day belongs to a catch-up sync that can
    /// ask the server which days it still wants. Re-reading a second day on every delivery
    /// doubled the reads and the posts for the whole day to cover one moment of it.
    ///
    /// - Parameters:
    ///   - date: The day the delivery woke on.
    ///   - read: Produces the activity for that day.
    ///   - report: Receives the outcome, before the delivery is acknowledged.
    ///   - acknowledge: HealthKit's completion handler for this specific delivery.
    static func processDelivery<Activity: Sendable>(
        date: Date,
        read: @Sendable (Date) async throws -> Activity,
        report: @Sendable (Result<Activity?, any Error>) -> Void,
        acknowledge: @Sendable () -> Void
    ) async {
        do {
            report(.success(try await read(date)))
        } catch {
            report(.failure(error))
        }

        acknowledge()
    }
}
