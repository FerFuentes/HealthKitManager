//
//  MindfulActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import Foundation

/// Protocol for accessing mindfulness session data from HealthKit.
///
/// Conform to this protocol to access total time spent in mindfulness sessions.
/// Also supports real-time background observation.
public protocol MindfulActivity {
    /// Gets mindful activity data for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: A `MindfulActivityData` object with total mindful seconds.
    func getMindfulActivityData(by date: Date) async throws -> MindfulActivityData
    
    /// Starts or stops observing mindful activity changes in the background.
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: Called when mindful activity data changes.
    func observeMindfulActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<MindfulActivityData?, Error>) -> Void)
}

extension MindfulActivity {
    public func getMindfulActivityData(by date: Date) async throws -> MindfulActivityData {
        try await HealthKitManager.shared.getMindfulActivity(date: date)
    }
    
    public func observeMindfulActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<MindfulActivityData?, Error>) -> Void) {
        HealthKitManager.shared.observeMindfulActivityQuery(start, completion: completion)
    }
}
