//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {

    
    internal func observeWalkingActivityInBackground(
        date: Date,
        types: Set<HKQuantityType>
    ) {
        var queryDescriptors: [HKQueryDescriptor] = []

        for type in types {
            queryDescriptors.append(HKQueryDescriptor(sampleType: type, predicate: self.getPredicate(date: date)))
        }
        
        let query = HKObserverQuery(queryDescriptors: queryDescriptors) { [weak self]  _, updatedSampleTypes, completionHandler, error in
            defer { completionHandler() }
        
            if let error = error {
                debugPrint("Error observing walking activity: \(error.localizedDescription)")
                return
            } else if let self = self {
                Task {
                    _walkingActivity = await self.getWalkingActivity(date: date)
                }
            }
        }

        healthStore.execute(query)
    }

    internal func getWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData {
        var steps: Double?
        var activeCalories: Double?
        var distanceMeters: Double?
        var durationMinutes: Double = 0.0
        var averageHeartRate: Double?

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
                        options: .cumulativeSum
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
    
    private func getWalkingActivity(date: Date) async -> WalkingActivityData {
        async let averageHeartRate = try await self.getAverageHeartRate(date: date)
        async let steps = try self.getStepCount(date: date)
        async let durationMinutes = try self.getTotalDurationInMinutes(date: date)
        async let distanceMeters = try self.getDistanceWalkingRunning(date: date, unit: .meter())
        async let activeCalories = try self.getActiveEnergyBurned(date: date)

        return await WalkingActivityData(
            date: date,
            steps: try? steps,
            activeCalories: try? activeCalories,
            distanceMeters: try? distanceMeters,
            durationMinutes: try? durationMinutes,
            averageHeartRate: try? averageHeartRate
        )
    }
}
