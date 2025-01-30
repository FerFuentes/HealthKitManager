//
//  FormatWorkout.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 27/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    @MainActor
    internal func formatWorkout(_ workouts: [HKWorkout]) async throws -> WorkoutData {
        let deviceType: String = "iOS"
        let dataSource: WorkoutSource = .healthKit
        
        var formattedWorkouts: [Workout] = []
        
        // Use a simple for loop to process each workout asynchronously
        for workout in workouts {
            if let formattedWorkout = await formatSingleWorkout(workout) {
                formattedWorkouts.append(formattedWorkout)
            }
        }
        
        // Return the formatted workout data
        return WorkoutData(deviceType: deviceType, dataSource: dataSource, workouts: formattedWorkouts)
    }
    
    @MainActor
    internal func formatSingleWorkout(_ workout: HKWorkout) async -> Workout? {
        
        let id = workout.uuid.uuidString
        let type = Workouts.from(activityType: workout.workoutActivityType)
        
        // Format the start and end times
        let startTime = workout.startDate
        let endTime = workout.endDate
    
        // Calculate duration in minutes
        let durationMinutes = workout.duration.minutes
        let restingHeartRate: Double? = try? await getRestingHeartRate(date: workout.startDate)
        
        let workoutMetadata = WorkoutMetadata(from: workout.metadata)
        let metadata: Metadata = await formatWorkouMetadata(workout)
        
        let formattedWorkout = Workout(
            id: id,
            type: type,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            restingHeartRate: restingHeartRate,
            averageMETs: workoutMetadata.averageMETs,
            indoorWorkout: workoutMetadata.indoorWorkout,
            timeZone: workoutMetadata.timeZone,
            humidityPorcentage: workoutMetadata.humidity,
            wetherTemperatureOnFahrenheit: workoutMetadata.temperature,
            metadata: metadata
        )
        
        return formattedWorkout
    }
    
    @MainActor
    internal func formatWorkouMetadata(_ workout: HKWorkout) async -> Metadata {

        let distanceMeters = workout
            .statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?
            .doubleValue(for: HKUnit.meter()) ?? 0.0
        
        let activeCalories = workout
            .statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: HKUnit.kilocalorie()) ?? 0.0
        
        let averageHeartRate: Double? = workout
            .statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            .rounded()

        let stepsCount: Double? = workout.statistics(for: HKQuantityType(.stepCount))?
            .sumQuantity()?
            .doubleValue(for: HKUnit.count())
        
        let allStatistics = workout.allStatistics
        debugPrint(allStatistics)

        return Metadata(
            distanceMeters: distanceMeters,
            activeCalories: activeCalories,
            totalCalories: nil,
            averageHeartRate: averageHeartRate,
            averagePace: nil,
            averageCadence: nil,
            averagePower: nil,
            averageSpeed: nil,
            steps: stepsCount
        )
    }
}
