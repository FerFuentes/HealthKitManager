//
//  WorkoutData.swift
//  AdvantaSample
//
//  Created by Fernando Fuentes on 24/01/25.
//

import Foundation

public struct WorkoutData: Codable {
    public let deviceType: String
    public let dataSource: WorkoutSource
    public let workouts: [Workout]
}

public struct Workout: Codable, Identifiable {
    public let id: String
    public let type: Workouts?
    public let startTime: Date
    public let endTime: Date
    public let durationMinutes: Double?
    public let restingHeartRate: Double?
    public let averageMETs: Double?
    public let indoorWorkout: Bool?
    public let timeZone: String?
    public let humidityPorcentage: Double?
    public let wetherTemperatureOnFahrenheit: Double?
    public let metadata: Metadata?
}

public struct Metadata: Codable {
    public let distanceMeters: Double?
    public let activeCalories: Double?
    public let totalCalories: Double?
    public let averageHeartRate: Double?
    public let averagePace: String?
    public let averageCadence: Double?
    public let averagePower: Double?
    public let averageSpeed: Double?
    public let steps: Double?
}
