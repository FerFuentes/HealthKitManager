//
//  WorkoutsActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/01/25.
//

import Foundation
import HealthKit

/// Protocol for accessing workout data from HealthKit.
///
/// Conform to this protocol to access workout sessions including duration, calories,
/// distance, and heart rate statistics. Also supports real-time background observation.
public protocol WorkoutsActivity {
    /// Gets raw HKWorkout objects for walking workouts on a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: Array of `HKWorkout` objects.
    func getHKWorkoutForWalking(by date: Date) async throws -> [HKWorkout]
    
    /// Gets raw HKWorkout objects for a specific workout type on a date.
    /// - Parameters:
    ///   - type: The workout type to filter by.
    ///   - date: The date to query.
    /// - Returns: Array of `HKWorkout` objects.
    func getHKWorkoutsByType(ofType type: Workouts, date: Date) async throws -> [HKWorkout]
    
    /// Gets all raw HKWorkout objects for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: Array of `HKWorkout` objects.
    func getAllHKWorkouts(date: Date) async throws -> [HKWorkout]
    
    /// Gets formatted walking workout data for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: A `WorkoutData` object with formatted workout information.
    func getWorkoutsForWalking(by date: Date) async throws -> WorkoutData
    
    /// Gets formatted workout data for a specific workout type on a date.
    /// - Parameters:
    ///   - type: The workout type to filter by.
    ///   - date: The date to query.
    /// - Returns: A `WorkoutData` object with formatted workout information.
    func getWorkoutsByType(ofType type: Workouts, date: Date) async throws -> WorkoutData
    
    /// Gets all formatted workout data for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: A `WorkoutData` object with formatted workout information.
    func getAllWorkouts(date: Date) async throws -> WorkoutData
    
    /// Starts or stops observing workout changes in the background.
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: Called when workout data changes.
    func observeWorkoutsInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WorkoutData?, Error>) -> Void)
}

extension WorkoutsActivity {

    public func getHKWorkoutForWalking(by date: Date) async throws -> [HKWorkout] {
        try await HealthKitManager.shared.getHKWorkoutForWalking(date: date)
    }

    public func getHKWorkoutsByType(ofType type: Workouts, date: Date) async throws -> [HKWorkout] {
        try await HealthKitManager.shared.getHKWorkouts(by: type, date: date)
    }

    public func getAllHKWorkouts(date: Date) async throws -> [HKWorkout] {
        try await HealthKitManager.shared.getAllHKWorkouts(date: date)
    }

    public func getWorkoutsForWalking(by date: Date) async throws -> WorkoutData {
        try await HealthKitManager.shared.getWorkoutsForWalking(date: date)
    }

    public func getWorkoutsByType(ofType type: Workouts, date: Date) async throws -> WorkoutData {
        try await HealthKitManager.shared.getWorkouts(by: type, date: date)
    }

    public func getAllWorkouts(date: Date) async throws -> WorkoutData {
        try await HealthKitManager.shared.getAllWorkouts(date: date)
    }
    
    public func observeWorkoutsInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WorkoutData?, Error>) -> Void) {
        HealthKitManager.shared.observeWorkoutsQuery(start, completion: completion)
    }
}
