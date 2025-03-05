//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    
    actor WalkingActivityStore {
        private(set) var steps: Double?
           private(set) var activeCalories: Double?
           private(set) var distanceMeters: Double?
           private(set) var durationMinutes: Double?
           private(set) var averageHeartRate: Double?

           func update(quantityType: HKQuantityType, value: Double) async {
               switch quantityType {
               case HKQuantityType(.heartRate): averageHeartRate = value
               case HKQuantityType(.stepCount): steps = value
               case HKQuantityType(.distanceWalkingRunning): distanceMeters = value
               case HKQuantityType(.activeEnergyBurned): activeCalories = value
               default: break
               }
           }

           func setDurationMinutes(_ value: Double) async { durationMinutes = value }
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
        let store = WalkingActivityStore()

        await withTaskGroup(of: (HKQuantityType?, Double?).self) { group in
            for sampleType in sampleTypes {
                guard let quantityType = sampleType as? HKQuantityType else { continue }

                group.addTask {
                    do {
                        let value: Double? = try await {
                            switch quantityType {
                            case HKQuantityType(.heartRate):
                                return try await self.getAverageHeartRate(date: date)
                            case HKQuantityType(.stepCount):
                                return try await self.getStepCount(date: date)
                            case HKQuantityType(.distanceWalkingRunning):
                                return try await self.getDistanceWalkingRunning(date: date, unit: .meter())
                            case HKQuantityType(.activeEnergyBurned):
                                return try await self.getActiveEnergyBurned(date: date)
                            default:
                                return nil
                            }
                        }()
                        return (quantityType, value)
                    } catch {
                        debugPrint("Error fetching \(quantityType.identifier): \(error.localizedDescription)")
                        return (quantityType, nil)
                    }
                }
            }

            group.addTask {
                do {
                    let duration = try await self.getTotalDurationInMinutes(date: date)
                    return (nil, duration)
                } catch {
                    debugPrint("Error fetching duration: \(error.localizedDescription)")
                    return (nil, nil)
                }
            }

            for await (quantityType, value) in group {
                guard let value = value else { continue }

                if let type = quantityType {
                    await store.update(quantityType: type, value: value)
                } else {
                    await store.setDurationMinutes(value)
                }
            }
        }

        return await WalkingActivityData(
            date: date,
            steps: store.steps,
            activeCalories: store.activeCalories,
            distanceMeters: store.distanceMeters,
            durationMinutes: store.durationMinutes,
            averageHeartRate: store.averageHeartRate
        )
    }

}
