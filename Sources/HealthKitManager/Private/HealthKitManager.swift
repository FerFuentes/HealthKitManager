// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import HealthKit


class HealthKitManager: @unchecked Sendable {
    
    private(set) var healthStore: HKHealthStore
    
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

    @MainActor
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
    
    internal func getPredicate(date: Date) -> NSCompoundPredicate {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let excludeManual = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [predicateForSamples, excludeManual])
    }
    
    internal func getDescriptor(date: Date, type: HKQuantityType, options: HKStatisticsOptions) -> HKStatisticsCollectionQueryDescriptor {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let anchorDate = calendar.date(bySetting: .hour, value: 0, of: startDate)!
        
        var interval = DateComponents()
        interval.day = 1
                
        return HKStatisticsCollectionQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: type, predicate: getPredicate(date: date)),
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
    
    internal func getPredicateForWorkouts(date: Date) ->  HKSamplePredicate<HKWorkout> {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        return HKSamplePredicate.workout(predicateForSamples)
    }
    
    internal func getDescriptorForWorkout(date: Date) -> HKSampleQueryDescriptor<HKWorkout> {
        let predicate = getPredicateForWorkouts(date: date)
        
        return HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }
    
    internal func getPredicateForSleep(date: Date) -> HKSamplePredicate<HKCategorySample> {
        let sleepSampleType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(byAdding: .hour, value: -9, to: calendar.startOfDay(for: date))!
        let endDate = calendar.date(byAdding: .hour, value: 15, to: calendar.startOfDay(for: date))!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        return HKSamplePredicate.categorySample(type: sleepSampleType, predicate: predicateForSamples)
    }
    
    internal func getDescriptorForSleep(date: Date)  -> HKSampleQueryDescriptor<HKCategorySample> {
        let predicate = getPredicateForSleep(date: date)
        
        return HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }

}
