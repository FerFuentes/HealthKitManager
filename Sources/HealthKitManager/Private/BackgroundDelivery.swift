//
//  BackgroundDelivery.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 30/01/25.
//
import HealthKit

extension HealthKitManager {
    
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
    
    internal func observeHealthKitQuery(date: Date, types: Set<HKQuantityType>) async throws -> Set<HKSampleType> {
        var queryDescriptors: [HKQueryDescriptor] = []
        for type in types {
            do {
                _ = try self.checkAuthorizationStatus(for: type)
                queryDescriptors.append(HKQueryDescriptor(sampleType: type, predicate: self.getPredicate(date: date)))
            } catch {
                debugPrint("Failed to authorize \(type): \(error.localizedDescription)")
            }
        }
        
        guard !queryDescriptors.isEmpty else { return [] }
        
        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let query = HKObserverQuery(queryDescriptors: queryDescriptors) { _, updatedSampleTypes, completionHandler, error in
                defer { completionHandler() }
                
                guard !didResume else { return }
                
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: updatedSampleTypes ?? [])
                }
                
                didResume = true
            }
            
            healthStore.execute(query)
        }
    }
    
}
