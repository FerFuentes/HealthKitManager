//
//  HealthActivitiesData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import Foundation
import HealthKit

public protocol HealthActivitiesData {
    func getStepsCount(by date: Date) async throws -> Int?
    func getTotalActiveMinutesWalking(by date: Date) async throws -> Double
    func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double?
    func getCaloriesBurned(by date: Date) async throws -> Double?
    @MainActor func getWalkingActivityData(by date: Date) async throws -> WalkingActivityData
}

extension HealthActivitiesData {
    
    @MainActor
    public func getStepsCount(by date: Date) async throws -> Int? {
        try await HealthKitManager.shared.getStepCount(date: date)
    }
    
    @MainActor
    public func getTotalActiveMinutesWalking(by date: Date) async throws -> Double {
        try await HealthKitManager.shared.getTotalDurationInMinutes(date: date)
    }
    
    @MainActor
    public func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double? {
        try await HealthKitManager.shared.getDistanceWalkingRunning(date: date, unit: unit)
    }
    
    @MainActor
    public func getCaloriesBurned(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getActiveEnergyBurned(date: Date())
    }
    
    @MainActor
    public func getWalkingActivityData(by date: Date) async throws -> WalkingActivityData {
        try await HealthKitManager.shared.getWalkingActivity(date: date)
    }
}
