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
/// - Note: Processing runs in an unstructured task, so the system can suspend the app between
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
    /// A read that returns `nil` is a delivery with nothing to report; it is still reported, as
    /// a success carrying no activity, so a subscriber can tell it apart from a failure.
    ///
    /// - Parameters:
    ///   - date: The day the delivery woke on, captured when it arrived rather than when this
    ///     runs — the two can straddle midnight, and reading the wrong day reads an empty one.
    ///   - read: Produces the activity for that day, or `nil` when there is nothing to report.
    ///   - report: Receives the outcome, before the delivery is acknowledged.
    ///   - acknowledge: HealthKit's completion handler for this specific delivery.
    static func processDelivery<Activity: Sendable>(
        date: Date,
        read: @Sendable (Date) async throws -> Activity?,
        report: @Sendable (Result<Activity?, any Error>) -> Void,
        acknowledge: @Sendable () -> Void
    ) async {
        defer { acknowledge() }

        do {
            report(.success(try await read(date)))
        } catch {
            report(.failure(error))
        }
    }
}
