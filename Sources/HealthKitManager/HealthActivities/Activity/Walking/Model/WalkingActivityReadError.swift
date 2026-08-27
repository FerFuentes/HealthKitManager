//
//  WalkingActivityReadError.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation

/// Failure modes of a walking activity read that callers must distinguish from "no data".
///
/// `WalkingActivityData` uses `nil` only for metrics HealthKit genuinely has no samples for.
/// This error covers reads that cannot be trusted, so callers can skip submitting values
/// instead of mistaking a broken read for an empty day.
public enum WalkingActivityReadError: Error {
    /// The HealthKit database is encrypted because the device is locked; nothing could be read.
    case databaseInaccessible
    /// Every attempted metric failed to read; returning data would fabricate an empty day.
    case allMetricsFailed(underlying: [any Error])
    /// Some metrics read and others failed. The day is real but the payload would be part
    /// fiction, and a consumer cannot tell a metric that failed from one with no samples —
    /// it posts both as zero, overwriting whatever the server already held for them.
    case metricsUnreadable(underlying: [any Error])
}

extension WalkingActivityReadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .databaseInaccessible:
            return "HealthKit database is inaccessible while the device is locked."
        case .allMetricsFailed(let underlying):
            return "Every walking activity metric failed to read: \(underlying.map(\.localizedDescription).joined(separator: "; "))"
        case .metricsUnreadable(let underlying):
            return "Some walking activity metrics failed to read: \(underlying.map(\.localizedDescription).joined(separator: "; "))"
        }
    }
}
