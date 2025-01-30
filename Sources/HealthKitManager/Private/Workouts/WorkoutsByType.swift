//
//  WorkoutsBy.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/01/25.
//

import Foundation
import HealthKit


extension HealthKitManager {
    @MainActor
    func getHKWorkouts(by type: Workouts, date: Date) async throws -> [HKWorkout] {

        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == type.activityType }

        return sample
    }
    
    @MainActor
    func getWorkouts(by type: Workouts, date: Date) async throws -> WorkoutData {
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == type.activityType }
        
        return try await formatWorkout(sample)
    }
}
