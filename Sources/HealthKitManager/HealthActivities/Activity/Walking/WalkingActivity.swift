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
    func getWalkingActivityData(by date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData
    func getAverageHeartRate(date: Date) async throws -> Double?
    
    func observeWalkingActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void)
    var walkingActivityCompletationHandler: HKObserverQueryCompletionHandler? { get  }
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
    
    public func getWalkingActivityData(by date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData {
        await HealthKitManager.shared.getWalkingActivity(date: date, sampleTypes: sampleTypes)
    }
    
    public func observeWalkingActivityInBackground(_ start: Bool, completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void) {
        HealthKitManager.shared.observeWalkingActivityQuery(start, completion: completion)
    }
    
    public var walkingActivityCompletationHandler: HKObserverQueryCompletionHandler? {
        HealthKitManager.shared.walkingActivityCompletionHandler
    }
    
    public func getAverageHeartRate(date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getAverageHeartRate(date: date)
    }
}
