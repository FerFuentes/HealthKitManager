//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    
    enum WalkingActivityKey: String {
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
                let activity = await self.getWalkingActivity(date: date)
                completion(.success(activity))
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
            guard let quantityType = sampleType as? HKQuantityType else { continue }
            do {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    averageHeartRate = try await self.getAverageHeartRate(date: date)
                    
                case HKQuantityType(.stepCount):
                    steps = try await self.getStepCount(date: date)
                    durationMinutes = try await self.getTotalDurationInMinutes(date: date)

                case HKQuantityType(.distanceWalkingRunning):
                    distanceMeters = try await self.getDistanceWalkingRunning(date: date, unit: .meter())

                case HKQuantityType(.activeEnergyBurned):
                    activeCalories = try await self.getActiveEnergyBurned(date: date)

                default:
                    print("Unknown quantity type")
                }
            } catch {
                debugPrint("Error fetching \(quantityType.identifier): \(error.localizedDescription)")
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
