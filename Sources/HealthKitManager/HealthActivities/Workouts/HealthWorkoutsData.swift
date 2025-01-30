//
//  HealthWorkoutsData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/01/25.
//

import Foundation
import HealthKit

public protocol HealthWorkoutsData {
    @MainActor func getHKWorkoutForWalking(by date: Date) async throws -> [HKWorkout]
    @MainActor func getHKWorkoutsByType(ofType type: Workouts, date: Date) async throws -> [HKWorkout]
    @MainActor func getAllHKWorkouts(date: Date) async throws -> [HKWorkout]
    
    
    @MainActor func getWorkoutsForWalking(by date: Date) async throws -> WorkoutData
    @MainActor func getWorkoutsByType(ofType type: Workouts, date: Date) async throws -> WorkoutData
    @MainActor func getAllWorkouts(date: Date) async throws -> WorkoutData
}

extension HealthWorkoutsData {
    
    @MainActor
    public func getHKWorkoutForWalking(by date: Date) async throws -> [HKWorkout] {
        try await HealthKitManager.shared.getHKWorkoutForWalking(date: date)
    }
        
    @MainActor
    public func getHKWorkoutsByType(ofType type: Workouts, date: Date) async throws -> [HKWorkout] {
        try await HealthKitManager.shared.getHKWorkouts(by: type, date: date)
    }
    
    @MainActor
    public func getAllHKWorkouts(date: Date) async throws -> [HKWorkout] {
        try await HealthKitManager.shared.getAllHKWorkouts(date: date)
    }
    
    @MainActor
    public func getWorkoutsForWalking(by date: Date) async throws -> WorkoutData {
        try await HealthKitManager.shared.getWorkoutsForWalking(date: date)
    }
    
    @MainActor
    public func getWorkoutsByType(ofType type: Workouts, date: Date) async throws -> WorkoutData {
        try await HealthKitManager.shared.getWorkouts(by: type, date: date)
    }
    
    @MainActor
    public func getAllWorkouts(date: Date) async throws -> WorkoutData {
        try await HealthKitManager.shared.getAllWorkouts(date: date)
    }
}
