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
}
