//
//  AllWorkouts.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 27/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    private func getPredicateForWorkouts(date: Date) ->  HKSamplePredicate<HKWorkout> {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        return HKSamplePredicate.workout(predicateForSamples)
    }
    
    private func getDescriptorForWorkout(date: Date) -> HKSampleQueryDescriptor<HKWorkout> {
        let predicate = getPredicateForWorkouts(date: date)
        
        return HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }
    
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
    
    @MainActor
    func getHKWorkoutForWalking(date: Date) async throws -> [HKWorkout] {
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == Workouts.walking.activityType }
            

        return sample
    }
    
    @MainActor
    func getWorkoutsForWalking(date: Date) async throws -> WorkoutData {
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == Workouts.walking.activityType }
        
        return try await formatWorkout(sample)
    }
    
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
