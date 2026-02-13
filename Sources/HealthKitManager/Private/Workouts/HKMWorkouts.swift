//
//  HKMWorkouts.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 27/01/25.
//

import Foundation
import HealthKit

internal extension HealthKitManager {
    
    // MARK: - Observer Query for Background Delivery
    
    /// Starts or stops observing workout changes using HKObserverQuery.
    ///
    /// This method sets up a real-time observer for workout data changes. When new workouts
    /// are recorded or modified, the completion handler is called with updated workout data.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when workout data changes.
    ///                 Returns `Result<WorkoutData?, Error>`.
    ///
    /// - Note: Enable background delivery using `enableBackgroundWorkoutsUpdates(enabled:)`
    ///         to receive updates when the app is in the background.
    func observeWorkoutsQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<WorkoutData?, Error>) -> Void
    ) {
        if start {
            guard workoutsObserverQuery == nil else {
                return
            }
            
            let workoutType = HKSampleType.workoutType()
            let query = HKObserverQuery(
                sampleType: workoutType,
                predicate: nil) { [weak self] query, completionHandler, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        clearWorkoutsObserverQuery()
                        debugPrint("Error observing workouts: \(error)")
                        completion(.failure(error))
                    } else {
                        Task {
                            do {
                                let workouts = try await self.getAllWorkouts(date: Date())
                                completion(.success(workouts))
                            } catch {
                                completion(.failure(error))
                            }
                        }
                    }
                    workoutsCompletionHandler = completionHandler
                }
            
            healthStore.execute(query)
            workoutsObserverQuery = query
        } else {
            if let query = workoutsObserverQuery {
                healthStore.stop(query)
                clearWorkoutsObserverQuery()
            }
        }
    }
    
    func clearWorkoutsObserverQuery() {
        workoutsCompletionHandler?()
        workoutsObserverQuery = nil
    }
    
    // MARK: - Predicates and Descriptors
    
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
    
    func getHKWorkouts(by type: Workouts, date: Date) async throws -> [HKWorkout] {

        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == type.activityType }

        return sample
    }

    func getWorkouts(by type: Workouts, date: Date) async throws -> WorkoutData {
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == type.activityType }
        
        return try await formatWorkout(sample)
    }

    func getHKWorkoutForWalking(date: Date) async throws -> [HKWorkout] {
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == Workouts.walking.activityType }
            

        return sample
    }

    func getWorkoutsForWalking(date: Date) async throws -> WorkoutData {
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { $0.workoutActivityType == Workouts.walking.activityType }
        
        return try await formatWorkout(sample)
    }

    func getAllHKWorkouts(date: Date) async throws -> [HKWorkout] {
        // Get all the allowed activity types from the Workouts enum
        let allowedActivityTypes = Set(Workouts.allCases.map { $0.activityType })
        
        let sample = try await getDescriptorForWorkout(
            date: date
        ).result(for: healthStore)
            .filter { allowedActivityTypes.contains($0.workoutActivityType) }
        
        return sample
    }

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
