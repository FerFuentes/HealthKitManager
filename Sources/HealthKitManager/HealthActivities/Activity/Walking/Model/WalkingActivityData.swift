//
//  WalkingActivityData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation

public struct WalkingActivityData: @unchecked Sendable, Codable {
    public let date: Date?
    public let steps: Double?
    public let activeCalories: Double?
    public let distanceMeters: Double?
    public let durationMinutes: Double?
    public let averageHeartRate: Double?
    
    public init(date: Date?, steps: Double?, activeCalories: Double?, distanceMeters: Double?, durationMinutes: Double?, averageHeartRate: Double?) {
        self.date = date
        self.steps = steps
        self.activeCalories = activeCalories
        self.distanceMeters = distanceMeters
        self.durationMinutes = durationMinutes
        self.averageHeartRate = averageHeartRate
    }
}
