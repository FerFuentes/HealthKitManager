//
//  SleepActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/02/25.
//

import Foundation

/// Protocol for accessing sleep analysis data from HealthKit.
///
/// Conform to this protocol to access sleep stages (REM, deep, core) and awake times.
/// Also supports real-time background observation.
public protocol SleepActivity {
    /// Gets sleep activity data for a specific date.
    /// - Parameter date: The date to query (queries previous night's sleep).
    /// - Returns: A `SleepActivityData` object with sleep stage durations.
    func getSleepActivityData(by date: Date) async throws -> SleepActivityData
    
    /// Starts or stops observing sleep activity changes in the background.
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: Called when sleep activity data changes.
    func observeSleepActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<SleepActivityData?, Error>) -> Void)
}

extension SleepActivity {
    public func getSleepActivityData(by date: Date) async throws -> SleepActivityData {
        try await HealthKitManager.shared.getSleepActivity(date: date)
    }
    
    public func observeSleepActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<SleepActivityData?, Error>) -> Void) {
        HealthKitManager.shared.observeSleepActivityQuery(start, completion: completion)
    }
}
