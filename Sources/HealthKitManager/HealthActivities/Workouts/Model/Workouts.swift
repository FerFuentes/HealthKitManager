//
//  Workouts.swift
//  AdvantaSample
//
//  Created by Fernando Fuentes on 24/01/25.
//

import HealthKit

public enum Workouts: String, Codable, CaseIterable, @unchecked Sendable {
    case walking = "Walking"
    case running = "Running"
    case cycling = "Cycling"
    case yoga = "Yoga"
    case swimming = "Swimming"
    case rowing = "Rowing"
    case functionalStrengthTraining = "Functional Training"
    case climbing = "Climbing"
    case dance = "Dance"
    case hiking = "Hiking"
    
    public var activityType: HKWorkoutActivityType {
        switch self {
        case .walking:
            return .walking
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .yoga:
            return .yoga
        case .swimming:
            return .swimming
        case .rowing:
            return .rowing
        case .functionalStrengthTraining:
            return .functionalStrengthTraining
        case .climbing:
            return .climbing
        case .dance:
            return .cardioDance
        case .hiking:
            return .hiking
        }
    }
    
    public static func from(activityType: HKWorkoutActivityType) -> Workouts? {
        return Workouts.allCases.first(where: { $0.activityType == activityType })
    }
}
