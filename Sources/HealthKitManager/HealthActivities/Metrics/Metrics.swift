//
//  Metrics.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/02/25.
//
import Foundation

/// Protocol for accessing heart rate and body metrics from HealthKit.
///
/// Conform to this protocol to access heart rate data (average, resting) and
/// body measurements (height, weight). Also supports real-time background observation.
public protocol Metrics {
    /// Gets heart rate metrics for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: A `HeartRateData` object with average and resting heart rate.
    func getHeartRateMetrics(by date: Date) async throws -> HeartRateData
    
    /// Gets body metrics (height, weight) for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: A `BodyData` object with height and weight.
    func getBodyMetrics(by date: Date) async -> BodyData
    
    /// Starts or stops observing heart rate changes in the background.
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: Called when heart rate data changes.
    func observeHeartRateInBackground(_ start: Bool, completion: @escaping @Sendable (Result<HeartRateData?, Error>) -> Void)
}

extension Metrics {
    public func getHeartRateMetrics(by date: Date) async throws -> HeartRateData {
        let manager = HealthKitManager.shared
        return try await manager.getHeartRate(date: date, sampleTypes: manager.forHeartRateQuantityType)
    }
    
    public func getBodyMetrics(by date: Date) async -> BodyData {
        let manager = HealthKitManager.shared
        return await manager.getBodyMetrics(date: date, sampleTypes: manager.forBodyMetricsQuantityType)
    }
    
    public func observeHeartRateInBackground(_ start: Bool, completion: @escaping @Sendable (Result<HeartRateData?, Error>) -> Void) {
        HealthKitManager.shared.observeHeartRateQuery(start, completion: completion)
    }
}
