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
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        var queryDescriptors: [HKQueryDescriptor] = []
        
        for type in forWalkingActivityQuantityType {
            queryDescriptors.append(HKQueryDescriptor(sampleType: type, predicate: self.getPredicate(date: date)))
        }
        
        //        let query = HKObserverQuery(queryDescriptors: queryDescriptors) { [weak self] _, updatedSampleTypes, completionHandler, error in
        //            defer { completionHandler() }
        //            guard let self = self else { return }
        //
        //            guard !self.walkigselQueryInProgress else { return }
        //
        //            Task {
        //                if let error = error {
        //                    completion(.failure(error))
        //                } else {
        //                    self.walkigselQueryInProgress = true
        //                    let activity = await self.getWalkingActivity(date: date)
        //                    self.walkigselQueryInProgress = false
        //                    completion(.success(activity))
        //                }
        //            }
        //        }
        
        let query = HKAnchoredObjectQuery(
            queryDescriptors: queryDescriptors,
            anchor: walkingActivityQueryAnchor,
            limit: HKObjectQueryNoLimit)
        { [weak self] (_, samplesOrNil, _, newAnchor, _)  in
            guard let self = self else { return }
            
            guard let samples = samplesOrNil else {
                completion(.success(nil))
                return
            }
            
            guard samples.last != nil else {
                completion(.success(nil))
                return
            }
            
            self.walkingActivityQueryAnchor = newAnchor
            
            Task {
                let activity = await self.getWalkingActivity(date: date)
                completion(.success(activity))
            }
            
        }
        
        query.updateHandler = { [weak self] (query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil) in
            guard let self = self else { return }
            
            guard let samples = samplesOrNil else {
                completion(.success(nil))
                return
            }
            
            guard samples.last != nil else {
                completion(.success(nil))
                return
            }
            
            self.walkingActivityQueryAnchor = newAnchor
            
            Task {
                let activity = await self.getWalkingActivity(date: date)
                completion(.success(activity))
            }
        }
        
        healthStore.execute(query)
    }
    
    internal func getWalkingActivity(date: Date) async -> WalkingActivityData {
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
