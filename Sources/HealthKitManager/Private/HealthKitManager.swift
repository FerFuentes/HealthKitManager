// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import HealthKit


internal class HealthKitManager: @unchecked Sendable {
    
    private(set) var healthStore: HKHealthStore = HKHealthStore()
    internal var walkingActivityAnchoredQuery: HKAnchoredObjectQuery?
    internal var walkingActivityObserverQuery: HKObserverQuery?
    internal var walkingActivityCompletionHandler: HKObserverQueryCompletionHandler?
    
    // Sleep Activity observer properties
    internal var sleepActivityObserverQuery: HKObserverQuery?
    internal var sleepActivityCompletionHandler: HKObserverQueryCompletionHandler?
    
    // Mindful Activity observer properties
    internal var mindfulActivityObserverQuery: HKObserverQuery?
    internal var mindfulActivityCompletionHandler: HKObserverQueryCompletionHandler?
    
    // Nutrition observer properties
    internal var nutritionObserverQuery: HKObserverQuery?
    internal var nutritionCompletionHandler: HKObserverQueryCompletionHandler?
    
    // Metrics (Heart Rate) observer properties
    internal var heartRateObserverQuery: HKObserverQuery?
    internal var heartRateCompletionHandler: HKObserverQueryCompletionHandler?
    
    // Workouts observer properties
    internal var workoutsObserverQuery: HKObserverQuery?
    internal var workoutsCompletionHandler: HKObserverQueryCompletionHandler?
    
    private init() { }
    
    static let shared = HealthKitManager()
    
    internal let forWalkingActivityQuantityType: Set = [
        HKQuantityType(.heartRate),
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
    ]
    
    internal let forDietaryNutritionQuantityType: Set = [
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.dietaryFatTotal),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryProtein)
    ]
    
    internal let forHeartRateQuantityType: Set = [
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate)
    ]
    
    internal let forBodyMetricsQuantityType: Set = [
        HKQuantityType(.height),
        HKQuantityType(.bodyMass)
    ]
    
    internal let forSleepActivityCategoryType: Set<HKSampleType> = [
        HKCategoryType(.sleepAnalysis)
    ]
    
    internal let forMindfulActivityCategoryType: Set<HKSampleType> = [
        HKCategoryType(.mindfulSession)
    ]
    
    internal let forWorkoutsSampleType: Set<HKSampleType> = [
        HKSampleType.workoutType()
    ]
    
    /// Generic method to observe HealthKit changes using HKObserverQuery with async/await.
    ///
    /// This method provides a reusable async/await pattern for observing HealthKit data changes.
    /// It can be used for custom observation scenarios beyond the built-in observer methods.
    ///
    /// - Parameters:
    ///   - sampleTypes: Set of HKSampleType to observe
    ///   - predicate: Optional predicate to filter the samples
    /// - Returns: Set of updated sample types
    /// - Throws: An error if the observation fails
    internal func observeHealthKitQuery(sampleTypes: Set<HKSampleType>, predicate: NSPredicate?) async throws -> Set<HKSampleType> {
        let queryDescriptors: [HKQueryDescriptor] = sampleTypes
            .map { type in
                HKQueryDescriptor(sampleType: type, predicate: predicate)
            }
        
        return try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var didResume = false
            let query = HKObserverQuery(queryDescriptors: queryDescriptors) { query, updatedSampleTypes, completionHandler, error in
                guard !didResume else { return }
                didResume = true
                
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: updatedSampleTypes ?? [])
                }
                
                completionHandler()
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Checks the authorization status for a specific HealthKit object type.
    /// - Parameter type: The HealthKit object type to check.
    /// - Returns: `true` if sharing is authorized.
    /// - Throws: `Permission.Error` if unavailable or permission needed.
    internal func checkAuthorizationStatus(for type: HKObjectType) throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw Permission.Error.unavailable
        }
        
        let statusForAuthorization = healthStore.authorizationStatus(for: type)
        switch statusForAuthorization {
        case .sharingAuthorized:
            return true
        case .notDetermined:
            throw Permission.Error.needToRequestPermission
        default:
            return false
        }
    }

    internal func statusForAuthorizationRequest(toWrite: Set<HKSampleType>, toRead: Set<HKObjectType>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw Permission.Error.unavailable
        }
        
        guard !toWrite.isEmpty || !toRead.isEmpty else {
            throw Permission.Error.invalidParameters("At least one of `toWrite` or `toRead` must contain elements.")
        }
        
        let statusForAuthorization = try await  healthStore.statusForAuthorizationRequest(toShare: toWrite, read: toRead)
        switch statusForAuthorization {
            
        case .shouldRequest:
            try await healthStore.requestAuthorization(toShare: toWrite, read: toRead)
        case .unnecessary:
            return
        case .unknown:
            throw Permission.Error.unavailable
        @unknown default:
            throw Permission.Error.unavailable
        }
    }
    
    internal func getPredicate(date: Date, excludeManual: Bool = true) -> NSCompoundPredicate {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        if excludeManual {
            let excludeManualPredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
            return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateForSamples, excludeManualPredicate])
        }
        
        return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateForSamples])
    }
    
    internal func getDescriptor(date: Date, type: HKQuantityType, options: HKStatisticsOptions, excludeManual: Bool = true) -> HKStatisticsCollectionQueryDescriptor {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let anchorDate = calendar.date(bySetting: .hour, value: 0, of: startDate)!
        
        var interval = DateComponents()
        interval.day = 1
                
        return HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: getPredicate(date: date, excludeManual: excludeManual)),
            options: options,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
    }
    
    internal func getPredicate(startDate: Date, endDate: Date) -> NSCompoundPredicate {
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let excludeManual = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateForSamples, excludeManual])
    }
    
    internal func getDescriptor(startDate: Date, endDate: Date, type: HKQuantityType, options: HKStatisticsOptions) -> HKStatisticsCollectionQueryDescriptor {
        let calendar = Calendar(identifier: .gregorian)
        let anchorDate = calendar.date(bySetting: .hour, value: 0, of: startDate)!
        
        var interval = DateComponents()
        interval.day = 1
                    
        return HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: getPredicate(startDate: startDate, endDate: endDate)),
            options: options,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
    }
    
    internal func backgroundDeliveryForReadTypes(enable: Bool, types: Set<HKQuantityType>) async {
        do {
            if enable {
                try await statusForAuthorizationRequest(toWrite: [], toRead: types)
                for type in types {
                    try await healthStore.enableBackgroundDelivery(for: type, frequency: .hourly)
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
    
    /// Enable or disable background delivery for any HKObjectType (quantity types, category types, etc.)
    internal func backgroundDeliveryForSampleTypes(enable: Bool, types: Set<HKSampleType>) async {
        do {
            if enable {
                try await statusForAuthorizationRequest(toWrite: [], toRead: types)
                for type in types {
                    try await healthStore.enableBackgroundDelivery(for: type, frequency: .hourly)
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
    
}
