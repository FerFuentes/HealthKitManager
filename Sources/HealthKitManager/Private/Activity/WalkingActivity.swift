//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {

    func getWalkingActivityInBakground(date: Date) async throws -> WalkingActivityData {
        let sample = try await observeHealthKitQuery(date: date, types: forWalkingActivityQuantityType)
        return try await getWalkingActivity(date: date, sampleTypes: sample)
    }
    
    func getWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async throws -> WalkingActivityData {
        var steps: Double?
        var activeCalories: Double?
        var durationMinutes: Double = 0.0
        var averageHeartRate: Double?
        var distanceMeters: Double?
        
        for sampleType in sampleTypes {
            guard let quantityType = sampleType as? HKQuantityType else {
                continue
            }
            switch quantityType {
                
            case HKQuantityType(.heartRate):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    averageHeartRate = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .discreteAverage
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .averageQuantity()?
                        .doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.stepCount):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    steps = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .cumulativeSum
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.count())
                    
                    let predicate = getPredicate(date: date)
                    
                    let totalDurationDescriptor = HKSampleQueryDescriptor(
                        predicates: [.quantitySample(type: quantityType, predicate: predicate)],
                        sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
                    )
                    
                    let stepSamples = try await totalDurationDescriptor.result(for: healthStore)
                    durationMinutes += stepSamples
                        .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60.0
                } catch {
                    debugPrint("Error fetching step count: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.distanceWalkingRunning):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    distanceMeters = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .cumulativeSum
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.meter())
                } catch {
                    debugPrint("Error fetching distance: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.activeEnergyBurned):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    activeCalories = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: []
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.kilocalorie())
                } catch {
                    debugPrint("Error fetching active calories: \(error.localizedDescription)")
                }
            default:
                print("Unknown quantity type")
            }
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
