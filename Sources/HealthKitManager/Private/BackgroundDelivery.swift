//
//  BackgroundDelivery.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//
import HealthKit

extension HealthKitManager {

    var anchor: HKQueryAnchor? {
        get {
            guard let data = UserDefaults.standard.data(forKey: walkingActivityQueryAnchor) else { return nil }
            do {
                return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
            } catch {
                print("❌ Unable to retrieve anchor")
                return nil
            }
        }
        set {
            guard let newAnchor = newValue else { return }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true)
                UserDefaults.standard.set(data, forKey: walkingActivityQueryAnchor)
            } catch {
                print("❌ Unable to store new anchor")
            }
        }
    }
    
    internal func bacgroundDelivery(enable: Bool, types: Set<HKQuantityType>) async {
        do {
            if enable {
                try await statusForAuthorizationRequest(toWrite: [], toRead: types)
                for type in types {
                    try await healthStore.enableBackgroundDelivery(for: type, frequency: .daily)
                }
            } else {
                for type in types {
                    try await healthStore.disableBackgroundDelivery(for: type)
                }
            }
            
        } catch {
            debugPrint("Error enabling background delivery: \(error.localizedDescription)")
        }
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
    
    internal func executeAnchoredQueryForWalkingActivity(
        date: Date,
        completion: @escaping @Sendable (Result<WalkingActivityData?, Error>) -> Void
    ) {
        var queryDescriptors: [HKQueryDescriptor] = []

        for type in forWalkingActivityQuantityType {
            do {
                _ = try self.checkAuthorizationStatus(for: type)
                queryDescriptors.append(HKQueryDescriptor(sampleType: type, predicate: self.getPredicate(date: date)))
            } catch {
                debugPrint("Failed to authorize \(type): \(error.localizedDescription)")
            }
        }
        
        let query = HKAnchoredObjectQuery(
            queryDescriptors: queryDescriptors,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { _, updatedSampleTypes, deletedObjectsOrNil, newAnchor, error in
            self.anchor = newAnchor
            
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let updatedSampleTypes = updatedSampleTypes, !updatedSampleTypes.isEmpty else {
                completion(.success(nil))
                return
            }
            
            let validSamples = updatedSampleTypes.compactMap { $0 as? HKQuantitySample }
            
            let sampleTypesSet: Set<HKSampleType> = Set(validSamples.map { $0.sampleType })
            Task {
                let activity = await self.getWalkingActivity(date: date, sampleTypes: sampleTypesSet)
                completion(.success(activity))
            }
        }
        
        healthStore.execute(query)
    }
}
