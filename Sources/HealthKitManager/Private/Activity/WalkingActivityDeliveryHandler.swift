//
//  WalkingActivityDeliveryHandler.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Bridges one HealthKit background delivery to async processing while honoring Apple's
/// acknowledgement contract: the delivery is acknowledged on every path, and only after
/// processing finished and the caller was notified. iOS permanently stops background
/// delivery for a sample type after three unacknowledged deliveries.
enum WalkingActivityDeliveryHandler {

    /// Processes one background delivery and acknowledges it exactly once, afterwards.
    ///
    /// - Parameters:
    ///   - read: Produces the walking activity for the delivery being processed.
    ///   - report: Receives the outcome, before the delivery is acknowledged.
    ///   - acknowledge: HealthKit's completion handler for this specific delivery.
    static func processDelivery(
        read: @Sendable () async throws -> WalkingActivityData,
        report: @Sendable (Result<WalkingActivityData?, any Error>) -> Void,
        acknowledge: @Sendable () -> Void
    ) async {
        do {
            let activity = try await read()
            report(.success(activity))
        } catch {
            report(.failure(error))
        }
        acknowledge()
    }
}
