//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    
    private enum WalkingActivityKey: String {
        case steps
        case calories
        case distance
        case duration
        case heartRate
    }

    internal func observeWalkingActivityInBackground(
        date: Date,
        types: Set<HKQuantityType>,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        var queryDescriptors: [HKQueryDescriptor] = []

        for type in types {
            do {
                _ = try self.checkAuthorizationStatus(for: type)
                queryDescriptors.append(HKQueryDescriptor(sampleType: type, predicate: self.getPredicate(date: date)))
            } catch {
                debugPrint("Failed to authorize \(type): \(error.localizedDescription)")
            }
        }

        let query = HKObserverQuery(queryDescriptors: queryDescriptors) { _, updatedSampleTypes, completionHandler, error in
            defer { completionHandler() }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let updatedSampleTypes = updatedSampleTypes, !updatedSampleTypes.isEmpty else {
                completion(.success(nil))
                return
            }
          
            Task {
                let activity = await self.getWalkingActivity(date: date, sampleTypes: updatedSampleTypes)
                completion(.success(activity))
            }
        }

        healthStore.execute(query)
    }

    internal func getWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData {
        var steps: Double?
        var activeCalories: Double?
        var distanceMeters: Double?
        var durationMinutes: Double?
        var averageHeartRate: Double?
            
        try? await withThrowingTaskGroup(of: (WalkingActivityKey, Double?).self) { group in
            for sampleType in sampleTypes {
                guard let quantityType = sampleType as? HKQuantityType else { continue }

                switch quantityType {
                case HKQuantityType(.heartRate):
                    group.addTask {
                        return (.heartRate, try await self.getAverageHeartRate(date: date))
                    }
                    
                case HKQuantityType(.stepCount):
                    group.addTask {
                        return (.steps, try await self.getStepCount(date: date))
                    }
                    group.addTask {
                        return (.duration, try await self.getTotalDurationInMinutes(date: date))
                    }

                case HKQuantityType(.distanceWalkingRunning):
                    group.addTask {
                        return (.distance, try await self.getDistanceWalkingRunning(date: date, unit: .meter()))
                    }

                case HKQuantityType(.activeEnergyBurned):
                    group.addTask {
                        return (.calories, try await self.getActiveEnergyBurned(date: date))
                    }

                default:
                    print("Unknown quantity type")
                }
            }

            for try await (key, value) in group {
                switch key {
                case .steps:
                    steps = value
                case .calories:
                    activeCalories = value
                case .distance:
                    distanceMeters = value
                case .duration:
                    durationMinutes = value
                case .heartRate:
                    averageHeartRate = value
                }
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
