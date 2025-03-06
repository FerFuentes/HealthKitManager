//
//  HealthActivitiesData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import Foundation
import HealthKit

public protocol WalkingActivity {
    func getStepsCount(by date: Date) async throws -> Double?
    func getTotalActiveMinutesWalking(by date: Date) async throws -> Double
    func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double?
    func getCaloriesBurned(by date: Date) async throws -> Double?
    func getWalkingActivityData(by date: Date) async -> WalkingActivityData
    func observeWalkingActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void)
    func getAverageHeartRate(date: Date) async throws -> Double?
    
}

extension WalkingActivity {
    
    public func getStepsCount(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getStepCount(date: date)
    }
    
    public func getTotalActiveMinutesWalking(by date: Date) async throws -> Double {
        try await HealthKitManager.shared.getTotalDurationInMinutes(date: date)
    }
    
    public func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double? {
        try await HealthKitManager.shared.getDistanceWalkingRunning(date: date, unit: unit)
    }
    
    public func getCaloriesBurned(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getActiveEnergyBurned(date: Date())
    }
    
    public func getWalkingActivityData(by date: Date) async -> WalkingActivityData {
        await HealthKitManager.shared.getWalkingActivity(date: date)
    }
    
    public func observeWalkingActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void) {
        return HealthKitManager.shared.observeWalkingActivityInBackground(start, completion: completion)
    }
    
    public func getAverageHeartRate(date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getAverageHeartRate(date: date)
    }
}
