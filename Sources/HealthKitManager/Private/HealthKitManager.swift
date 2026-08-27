// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import HealthKit


internal class HealthKitManager: @unchecked Sendable {
    
    private(set) var healthStore: HKHealthStore = HKHealthStore()
    internal let walkingActivityObservation = HealthKitObservationCoordinator<WalkingActivityData>()
    private let backgroundTypesLock = NSLock()
    private var enabledWalkingActivityBackgroundTypes: Set<HKQuantityType>?
    
    internal let sleepActivityObservation = HealthKitObservationCoordinator<SleepActivityData>()
    internal let mindfulActivityObservation = HealthKitObservationCoordinator<MindfulActivityData>()
    internal let nutritionObservation = HealthKitObservationCoordinator<DietaryNutritionData>()
    internal let heartRateObservation = HealthKitObservationCoordinator<HeartRateData>()
    internal let workoutsObservation = HealthKitObservationCoordinator<WorkoutData>()
    
    private init() { }
    
    static let shared = HealthKitManager()
    
    internal let forWalkingActivityQuantityType: Set = [
        HKQuantityType(.heartRate),
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
    ]
    
    /// The metrics one walking delivery reads, whichever types woke it.
    ///
    /// Waking and reading are separate questions, and answering both with the enabled set
    /// silently truncated the payload: a caller that narrowed its wake-ups to steps started
    /// posting a day with no distance and no calories, which the server stores as zeros over
    /// values it already held. Heart rate stays out — it lands continuously and belongs to
    /// the foreground syncs that ask for it by name.
    internal var walkingActivityDeliverySampleTypes: Set<HKSampleType> {
        Set(forWalkingActivityQuantityType.subtracting([HKQuantityType(.heartRate)]).map { $0 as HKSampleType })
    }

    /// The walking types currently enabled for background delivery — what wakes the app —
    /// falling back to the package defaults until the caller enables an explicit set. The
    /// observer registers exactly these, so no enabled type can deliver without a handler
    /// to acknowledge it.
    internal var walkingActivityBackgroundTypes: Set<HKQuantityType> {
        backgroundTypesLock.withLock { enabledWalkingActivityBackgroundTypes ?? forWalkingActivityQuantityType }
    }

    /// Records which walking types background delivery is actually live for, so the observer
    /// can watch exactly what can wake it. A live observation re-registers its descriptors when
    /// this changes; without that the observer would keep watching the set it started with and
    /// a newly enabled type would deliver with nothing to acknowledge it.
    ///
    /// - Parameter types: The types delivery is live for, or `nil` once none are.
    internal func rememberWalkingActivityBackgroundTypes(_ types: Set<HKQuantityType>?) {
        let changed = backgroundTypesLock.withLock { () -> Bool in
            guard enabledWalkingActivityBackgroundTypes != types else { return false }
            enabledWalkingActivityBackgroundTypes = types
            return true
        }

        guard changed else { return }
        walkingActivityObservation.reregisterIfObserving()
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
    /// Enabling requires authorization to be established already: this never presents the
    /// permission sheet, because it runs from app-startup paths where no user action
    /// happened. Disabling is always attempted, even when HealthKit reports itself
    /// unavailable, so teardown can never be blocked.
    ///
    /// Every type is attempted; the failures are collected rather than aborting the set
    /// half-toggled.
    ///
    /// - Parameters:
    ///   - enable: `true` to enable delivery, `false` to disable it.
    ///   - types: The sample types to toggle.
    ///   - authorizedTypes: The types authorization must cover, when that is wider than the
    ///     types being toggled — a caller whose deliveries read more than they wake on must
    ///     name the whole read here, or an unauthorized read arrives as an empty day rather
    ///     than as an error. Defaults to `types`.
    /// - Throws: A `Permission.Error` when enabling without established authorization, or
    ///   ``BackgroundDeliveryError`` naming the types that could not be toggled.
    internal func setBackgroundDelivery(
        enable: Bool,
        types: Set<HKSampleType>,
        requiringAuthorizationFor authorizedTypes: Set<HKSampleType>? = nil
    ) async throws {
        if enable {
            try await requireEstablishedAuthorization(toRead: authorizedTypes ?? types)
        }

        var failures: [(type: HKSampleType, error: any Error)] = []
        for type in types {
            do {
                if enable {
                    try await healthStore.enableBackgroundDelivery(for: type, frequency: .hourly)
                } else {
                    try await healthStore.disableBackgroundDelivery(for: type)
                }
            } catch {
                failures.append((type, error))
            }
        }

        if let failure = BackgroundDeliveryError(failures: failures) {
            throw failure
        }
    }

    
}
