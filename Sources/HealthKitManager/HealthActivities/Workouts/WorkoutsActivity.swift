//
//  HealthWorkoutsData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/01/25.
//

import Foundation
import HealthKit

public protocol WorkoutsActivity {
    func getHKWorkoutForWalking(by date: Date) async throws -> [HKWorkout]
    func getHKWorkoutsByType(ofType type: Workouts, date: Date) async throws -> [HKWorkout]
    func getAllHKWorkouts(date: Date) async throws -> [HKWorkout]
    
    
    func getWorkoutsForWalking(by date: Date) async throws -> WorkoutData
    func getWorkoutsByType(ofType type: Workouts, date: Date) async throws -> WorkoutData
    func getAllWorkouts(date: Date) async throws -> WorkoutData
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
}
