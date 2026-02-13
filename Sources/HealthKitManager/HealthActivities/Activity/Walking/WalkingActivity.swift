//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import Foundation
import HealthKit

/// Protocol for accessing walking and running activity data from HealthKit.
///
/// Conform to this protocol to access step counts, distance, calories burned,
/// and heart rate data. Also supports real-time background observation.
public protocol WalkingActivity {
    /// Gets the step count for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: The total step count, or `nil` if unavailable.
    func getStepsCount(by date: Date) async throws -> Double?
    
    /// Gets the total active walking minutes for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: Total active minutes.
    func getTotalActiveMinutesWalking(by date: Date) async throws -> Double
    
    /// Gets the walking and running distance for a specific date.
    /// - Parameters:
    ///   - date: The date to query.
    ///   - unit: The unit for the distance (e.g., `.meter()`, `.mile()`).
    /// - Returns: The distance in the specified unit, or `nil` if unavailable.
    func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double?
    
    /// Gets the active calories burned for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: Active calories in kcal, or `nil` if unavailable.
    func getCaloriesBurned(by date: Date) async throws -> Double?
    
    /// Gets complete walking activity data for a specific date.
    /// - Parameters:
    ///   - date: The date to query.
    ///   - sampleTypes: The set of sample types to include in the response.
    /// - Returns: A `WalkingActivityData` object with all requested metrics.
    func getWalkingActivityData(by date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData
    
    /// Gets the average heart rate for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: Average heart rate in BPM, or `nil` if unavailable.
    func getAverageHeartRate(date: Date) async throws -> Double?
    
    /// Starts or stops observing walking activity changes in the background.
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: Called when walking activity data changes.
    func observeWalkingActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void)
}

extension WalkingActivity {
    
    public func getStepsCount(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getStepCount(date: date)
    }
    
    public func getTotalActiveMinutesWalking(by date: Date) async throws -> Double {
        try await HealthKitManager.shared.getTotalDurationInMinutes(date: date)
    }
    
    public func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double? {
        try await HealthKitManager.shared.getDistanceWalkingRunning(date: date, unit: unit)
    }
    
    public func getCaloriesBurned(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getActiveEnergyBurned(date: Date())
    }
    
    public func getWalkingActivityData(by date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData {
        await HealthKitManager.shared.getWalkingActivity(date: date, sampleTypes: sampleTypes)
    }
    
    public func observeWalkingActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void) {
        HealthKitManager.shared.observeWalkingActivityQuery(start, completion: completion)
    }
    
    public func getAverageHeartRate(date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getAverageHeartRate(date: date)
    }
}
