//
//  FormatWorkout.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 27/01/25.
//

import Foundation
import HealthKit

internal extension HealthKitManager {
    func formatWorkout(_ workouts: [HKWorkout]) async throws -> WorkoutData {
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

    func formatSingleWorkout(_ workout: HKWorkout) async -> Workout? {
        
        let id = workout.uuid.uuidString
        let type = Workouts.from(activityType: workout.workoutActivityType)
        let source = workout.sourceRevision.source.name
        let startTime = workout.startDate
        let endTime = workout.endDate
    
        let durationMinutes = workout.duration.minutes
        let restingHeartRate: Double? = try? await getRestingHeartRate(date: workout.startDate)
    
        let metadata: Metadata = formatWorkouMetadata(workout.metadata)
        let appStatistics: Statistics = formatAllStatistics(workout)
        
        let formattedWorkout = Workout(
            id: id,
            type: type,
            source: source,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: durationMinutes,
            restingHeartRate: restingHeartRate,
            metadata: metadata,
            statistics: appStatistics
        )
        
        return formattedWorkout
    }
    
    func formatWorkouMetadata(_ metadata: [String : Any]?) -> Metadata {
        let workoutMetadata = WorkoutMetadata(from: metadata)
        
        return Metadata(
            averageMETs: workoutMetadata.averageMETs,
            indoorWorkout: workoutMetadata.indoorWorkout,
            timeZone: workoutMetadata.timeZone,
            humidityPorcentage: workoutMetadata.humidity,
            wetherTemperatureOnFahrenheit: workoutMetadata.temperature
        )

    }
    
    func formatAllStatistics(_ workout: HKWorkout) -> Statistics {

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

        return Statistics(
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
