// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import HealthKit


internal class HealthKitManager: @unchecked Sendable {
    
    private(set) var healthStore: HKHealthStore = HKHealthStore()
    internal var walkingActivityAnchoredQuery: HKAnchoredObjectQuery?
    internal let walkingActivityObservation = HealthKitObservationCoordinator<WalkingActivityData>()
    private let backgroundTypesLock = NSLock()
    private var enabledWalkingActivityBackgroundTypes: Set<HKQuantityType>?
    
    internal var sleepActivityObserverQuery: HKObserverQuery?
    internal var mindfulActivityObserverQuery: HKObserverQuery?
    internal var nutritionObserverQuery: HKObserverQuery?
    internal var heartRateObserverQuery: HKObserverQuery?
    internal var workoutsObserverQuery: HKObserverQuery?
    
    private init() { }
    
    static let shared = HealthKitManager()
    
    internal let forWalkingActivityQuantityType: Set = [
        HKQuantityType(.heartRate),
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
    ]
    
    /// The walking types currently enabled for background delivery, falling back to the
    /// package defaults until the caller enables an explicit set. The observer registers
    /// exactly these, so no enabled type can deliver without a handler to acknowledge it.
    internal var walkingActivityBackgroundTypes: Set<HKQuantityType> {
        backgroundTypesLock.withLock { enabledWalkingActivityBackgroundTypes ?? forWalkingActivityQuantityType }
    }

    internal var walkingActivityBackgroundSampleTypes: Set<HKSampleType> {
        Set(walkingActivityBackgroundTypes.map { $0 as HKSampleType })
    }

    /// Records which walking types background delivery was last enabled for, so the
    /// observer and the reads follow the same set.
    ///
    /// - Parameter types: The enabled types, or `nil` once delivery is disabled.
    internal func rememberWalkingActivityBackgroundTypes(_ types: Set<HKQuantityType>?) {
        backgroundTypesLock.withLock { enabledWalkingActivityBackgroundTypes = types }
    }

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
    
    /// Validates that authorization has already been requested, without ever presenting
    /// the permission sheet, so background-delivery setup at cold launch stays silent.
    ///
    /// - Parameter status: The store's authorization request status for the types involved.
    /// - Throws: `Permission.Error.needToRequestPermission` when the app has not asked the
    ///   user yet, or `Permission.Error.unavailable` when the status cannot be determined.
    internal static func requireEstablishedAuthorization(_ status: HKAuthorizationRequestStatus) throws {
        switch status {
        case .unnecessary:
            return
        case .shouldRequest:
            throw Permission.Error.needToRequestPermission
        case .unknown:
            throw Permission.Error.unavailable
        @unknown default:
            throw Permission.Error.unavailable
        }
    }

    /// Validates that authorization for the given types has already been requested,
    /// without ever presenting the permission sheet.
    ///
    /// - Parameter types: The types to be read.
    /// - Throws: `Permission.Error` when HealthKit is unavailable, no type was given, or
    ///   the user was never asked.
    internal func requireEstablishedAuthorization(toRead types: Set<HKSampleType>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw Permission.Error.unavailable
        }
        guard !types.isEmpty else {
            throw Permission.Error.invalidParameters("At least one type to read must be provided.")
        }

        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
        try Self.requireEstablishedAuthorization(status)
    }

    /// Enables or disables hourly background delivery for the given sample types.
    ///
    /// Authorization must already be established: this never presents the permission sheet,
    /// because it runs from app-startup paths where no user action happened.
    ///
    /// - Parameters:
    ///   - enable: `true` to enable delivery, `false` to disable it.
    ///   - types: The sample types to toggle.
    /// - Throws: A `Permission.Error` when HealthKit is unavailable or authorization was
    ///   never requested, or the first `HKHealthStore` failure while toggling a type.
    internal func setBackgroundDelivery(enable: Bool, types: Set<HKSampleType>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw Permission.Error.unavailable
        }

        if enable {
            try await requireEstablishedAuthorization(toRead: types)
            for type in types {
                try await healthStore.enableBackgroundDelivery(for: type, frequency: .hourly)
            }
        } else {
            for type in types {
                try await healthStore.disableBackgroundDelivery(for: type)
            }
        }
    }
    
}
