//
//  AllWorkouts.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 27/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {    
    @MainActor
    func getAllHKWorkouts(date: Date) async throws -> [HKWorkout] {
        // Get all the allowed activity types from the Workouts enum
        let allowedActivityTypes = Set(Workouts.allCases.map { $0.activityType })
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { allowedActivityTypes.contains($0.workoutActivityType) }
        
        return sample
    }
    
    @MainActor
    func getAllWorkouts(date: Date) async throws -> WorkoutData {
        // Get all the allowed activity types from the Workouts enum
        let allowedActivityTypes = Set(Workouts.allCases.map { $0.activityType })
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { allowedActivityTypes.contains($0.workoutActivityType) }
        
        return try await formatWorkout(sample)
    }
    
}
