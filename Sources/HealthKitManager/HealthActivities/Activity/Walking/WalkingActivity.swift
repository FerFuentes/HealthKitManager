//
//  HealthActivitiesData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import Foundation
import HealthKit
import Combine

public protocol WalkingActivity {
    func getStepsCount(by date: Date) async throws -> Double?
    func getTotalActiveMinutesWalking(by date: Date) async throws -> Double
    func getDistanceByWalkingAndRunning(by date: Date, unit: HKUnit) async throws -> Double?
    func getCaloriesBurned(by date: Date) async throws -> Double?
    func getWalkingActivityData(by date: Date) async -> WalkingActivityData
    func getAverageHeartRate(date: Date) async throws -> Double?
    
    func observeWalkingActivityInBackground(by date: Date)
    var walkingActivityData: Published<WalkingActivityData?>.Publisher { get }
}

extension WalkingActivity {
    
    public var walkingActivityData: Published<WalkingActivityData?>.Publisher {
        return HealthKitManager.shared.$_walkingActivity
    }
    
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
        let manager = HealthKitManager.shared
        return await manager.getWalkingActivity(date: date, sampleTypes: manager.forWalkingActivityQuantityType)
    }
    
    public func observeWalkingActivityInBackground(by date: Date) {
        let manager = HealthKitManager.shared
        return manager.observeWalkingActivityInBackground(date: date, types: manager.forWalkingActivityQuantityType)
    }
    
    public func getAverageHeartRate(date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getAverageHeartRate(date: date)
    }
}
