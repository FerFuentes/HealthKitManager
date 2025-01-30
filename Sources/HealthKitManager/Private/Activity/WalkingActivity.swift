//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    @MainActor
    func getWalkingActivity(date: Date) async throws -> WalkingActivityData {
        var steps: Double?
        var activeCalories: Double?
        var durationMinutes: Double = 0.0
        var averageHeartRate: Double?
        var distanceMeters: Double?
        
        let heartRateType = HKQuantityType(.heartRate)
        do {
            try checkAuthorizationStatus(for: heartRateType)
            averageHeartRate = try await getDescriptor(
                date: date,
                type: heartRateType,
                options: .discreteAverage
            ).result(for: healthStore)
                .statistics(for: date)?
                .averageQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        } catch {
            debugPrint("Error fetching heart rate: \(error.localizedDescription)")
        }
        
        let stepCountType = HKQuantityType(.stepCount)
        do {
            try checkAuthorizationStatus(for: stepCountType)
            steps = try await getDescriptor(
                date: date,
                type: stepCountType,
                options: .cumulativeSum
            ).result(for: healthStore)
                .statistics(for: date)?
                .sumQuantity()?
                .doubleValue(for: HKUnit.count())
            
            let predicate = getPredicate(date: date)
            
            let totalDurationDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: stepCountType, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
            )
            
            let stepSamples = try await totalDurationDescriptor.result(for: healthStore)
            durationMinutes += stepSamples
                .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60.0
        } catch {
            debugPrint("Error fetching step count: \(error.localizedDescription)")
        }
        
        let distanceWalkingRunningType = HKQuantityType(.distanceWalkingRunning)
        do {
            try checkAuthorizationStatus(for: distanceWalkingRunningType)
            distanceMeters = try await getDescriptor(
                date: date,
                type: distanceWalkingRunningType,
                options: .cumulativeSum
            ).result(for: healthStore)
                .statistics(for: date)?
                .sumQuantity()?
                .doubleValue(for: HKUnit.meter())
        } catch {
            debugPrint("Error fetching distance: \(error.localizedDescription)")
        }
        
        let activeEnergyBurnType = HKQuantityType(.activeEnergyBurned)
        do {
            try checkAuthorizationStatus(for: activeEnergyBurnType)
            activeCalories = try await getDescriptor(
                date: date,
                type: activeEnergyBurnType,
                options: []
            ).result(for: healthStore)
                .statistics(for: date)?
                .sumQuantity()?
                .doubleValue(for: HKUnit.kilocalorie())
        } catch {
            debugPrint("Error fetching active calories: \(error.localizedDescription)")
        }
        
        return WalkingActivityData(
            date: date,
            steps: steps,
            activeCalories: activeCalories,
            distanceMeters: distanceMeters,
            durationMinutes: durationMinutes,
            averageHeartRate: averageHeartRate
        )
    }
}
