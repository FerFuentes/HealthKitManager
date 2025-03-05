// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import HealthKit


class HealthKitManager: @unchecked Sendable {
    
    private(set) var healthStore: HKHealthStore
    internal let walkingActivityQueryAnchor = "WalkingActivityQueryAnchor"
    
    
    @Published internal var _walkingActivity: WalkingActivityData?
    public var walkingActivity: Published<WalkingActivityData?>.Publisher { $_walkingActivity }
    
    private init(
        healthStore: HKHealthStore = HKHealthStore()
    ) {
        self.healthStore = healthStore
    }
    
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
    
}
