//
//  PartialMetricRead.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Decides whether a read that failed for some of its metrics can still be trusted.
///
/// A read that produced at least one real value is reported as-is, with the failed metrics
/// absent. A read where everything either failed or came back empty is indistinguishable
/// from a genuinely empty day, so its failure is surfaced instead.
enum PartialMetricRead {

    /// The failure to surface for a partial read, if it cannot be trusted.
    ///
    /// - Parameters:
    ///   - readValues: The values of every metric that read successfully.
    ///   - failures: The errors of every metric that failed.
    /// - Returns: The failure to throw, or `nil` when the read can be reported.
    static func failureToSurface(readValues: [Double?], failures: [any Error]) -> (any Error)? {
        guard !failures.isEmpty else { return nil }
        if let lockedDatabase = failures.first(where: { $0.isHealthKitDatabaseInaccessible }) {
            return lockedDatabase
        }
        guard readValues.compactMap({ $0 }).isEmpty else { return nil }
        return failures.first
    }
}
