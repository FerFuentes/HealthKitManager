//
//  WalkingActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//

import Foundation
import HealthKit

extension HealthKitManager {
    
    internal var walkingActivityQueryAnchor: HKQueryAnchor? {
        get {
            if let anchorData = UserDefaults.standard.data(forKey: "walkingActivityAnchor") {
                return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
            }
            return nil
        }
        set {
            if let newAnchor = newValue {
                let anchorData = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                UserDefaults.standard.set(anchorData, forKey: "walkingActivityAnchor")
            } else {
                UserDefaults.standard.removeObject(forKey: "walkingActivityAnchor")
            }
        }
    }
    
    internal func observeWalkingActivityAnchoredObjectQuery(
        _ start: Bool,
        toRead: Set<HKQuantityType>,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        if start {
            guard (walkingActivityAnchoredQuery == nil) else {
                return
            }
            
            let predicate = getPredicate(date: Date())
            let queryDescriptors = toRead.map {
                HKQueryDescriptor(sampleType: $0, predicate: predicate)
            }

            let handleSamples: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { [weak self] _, samples, _, newAnchor, error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let samples = samples, !samples.isEmpty else {
                    completion(.success(nil))
                    return
                }

                Task {
                    self.walkingActivityQueryAnchor = newAnchor
                    
                    let activity = await self.getWalkingActivity(date: Date())
                    completion(.success(activity))
                }
            }

            let query = HKAnchoredObjectQuery(
                queryDescriptors: queryDescriptors,
                anchor: walkingActivityQueryAnchor,
                limit: HKObjectQueryNoLimit,
                resultsHandler: handleSamples
            )

            query.updateHandler = handleSamples
            healthStore.execute(query)
            
            walkingActivityAnchoredQuery = query
        } else {
            if let query = walkingActivityAnchoredQuery {
                healthStore.stop(query)
                walkingActivityAnchoredQuery = nil
            }
        }
    }
    
    internal func observeWalkingActivityObserverQuery(
        _ start: Bool,
        toRead: Set<HKQuantityType>,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        if start {
            guard (walkingActivityObserverQuery == nil) else {
                return
            }
            
            let predicate = getPredicate(date: Date())
            let queryDescriptors = toRead.map {
                HKQueryDescriptor(sampleType: $0, predicate: predicate)
            }

            let updateHandler: @Sendable (HKObserverQuery, Set<HKSampleType>?, @escaping HKObserverQueryCompletionHandler, (any Error)?) -> Void = { [weak self] query, sampleTypes, completionHandler, error in
                guard let self = self else { return }
                
                if let error = error  {
                    debugPrint("Error observing walking activity: \(error)")
                    completion(.failure(error))
                } else {
                    Task {
                        let activity = await self.getWalkingActivity(date: Date())
                        completion(.success(activity))
                    }
                }
                
            }
            
            let query = HKObserverQuery(
                queryDescriptors: queryDescriptors,
                updateHandler: updateHandler)
            
            healthStore.execute(query)

            walkingActivityObserverQuery = query
        } else {
            if let query = walkingActivityObserverQuery {
                healthStore.stop(query)
                walkingActivityObserverQuery = nil
            }
        }
    }
    
    public func getWalkingActivity(date: Date, sampleTypes: Set<HKSampleType>) async -> WalkingActivityData {
        do {
            try await statusForAuthorizationRequest(toWrite: [], toRead: sampleTypes)
        } catch {
            debugPrint("Error requesting authorization: \(error.localizedDescription)")
        }
        
        async let heartRateResult: Double? = sampleTypes.contains(HKQuantityType(.heartRate)) ? {
            do { return try await self.getAverageHeartRate(date: date) }
            catch { debugPrint("Error fetching heart rate: \(error.localizedDescription)"); return nil }
        }() : nil

        async let stepsResult: Double? = sampleTypes.contains(HKQuantityType(.stepCount)) ? {
            do { return try await self.getStepCount(date: date) }
            catch { debugPrint("Error fetching step count: \(error.localizedDescription)"); return nil }
        }() : nil

        async let durationResult: Double? = sampleTypes.contains(HKQuantityType(.stepCount)) ? {
            do { return try await self.getTotalDurationInMinutes(date: date) }
            catch { debugPrint("Error fetching duration: \(error.localizedDescription)"); return nil }
        }() : nil

        async let distanceResult: Double? = sampleTypes.contains(HKQuantityType(.distanceWalkingRunning)) ? {
            do { return try await self.getDistanceWalkingRunning(date: date, unit: .meter()) }
            catch { debugPrint("Error fetching distance: \(error.localizedDescription)"); return nil }
        }() : nil

        async let activeCaloriesResult: Double? = sampleTypes.contains(HKQuantityType(.activeEnergyBurned)) ? {
            do { return try await self.getActiveEnergyBurned(date: date) }
            catch { debugPrint("Error fetching active calories: \(error.localizedDescription)"); return nil }
        }() : nil

        return WalkingActivityData(
            date: date,
            steps: await stepsResult,
            activeCalories: await activeCaloriesResult,
            distanceMeters: await distanceResult,
            durationMinutes: await durationResult ?? 0.0,
            averageHeartRate: await heartRateResult
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
