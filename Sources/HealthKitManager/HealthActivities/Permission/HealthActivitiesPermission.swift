//
//  HealthActivitiesPermission.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import HealthKit

/// Protocol for managing HealthKit authorization and background delivery settings.
///
/// Conform to this protocol to request HealthKit permissions and enable/disable
/// background delivery for various health data types.
public protocol HealthActivitiesPermission {
    /// Requests HealthKit authorization for the specified types.
    /// - Parameters:
    ///   - toWrite: Set of sample types the app needs write access to.
    ///   - toRead: Set of object types the app needs read access to.
    func statusForHealthKitAuthorizationRequest(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws
    
    /// Checks if authorization is needed for a specific HealthKit type.
    /// - Parameter type: The HealthKit object type to check.
    /// - Returns: `true` if authorized, `false` otherwise.
    func isAuthorizationRequestNeeded(for type: HKObjectType) throws -> Bool
    
    // MARK: - Background Delivery Methods
    
    /// Enables or disables background delivery for walking activity updates.
    /// - Parameters:
    ///   - enabled: `true` to enable, `false` to disable.
    ///   - toRead: Optional set of quantity types. Defaults to steps, heart rate, distance, and calories.
    func enableBackgroundWalkingActivityUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async
    
    /// Enables or disables background delivery for sleep activity updates.
    /// - Parameter enabled: `true` to enable, `false` to disable.
    func enableBackgroundSleepActivityUpdates(enabled: Bool) async
    
    /// Enables or disables background delivery for mindful activity updates.
    /// - Parameter enabled: `true` to enable, `false` to disable.
    func enableBackgroundMindfulActivityUpdates(enabled: Bool) async
    
    /// Enables or disables background delivery for nutrition updates.
    /// - Parameters:
    ///   - enabled: `true` to enable, `false` to disable.
    ///   - toRead: Optional set of quantity types. Defaults to calories, carbs, protein, and fat.
    func enableBackgroundNutritionUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async
    
    /// Enables or disables background delivery for heart rate updates.
    /// - Parameters:
    ///   - enabled: `true` to enable, `false` to disable.
    ///   - toRead: Optional set of quantity types. Defaults to heart rate and resting heart rate.
    func enableBackgroundHeartRateUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async
    
    /// Enables or disables background delivery for workout updates.
    /// - Parameter enabled: `true` to enable, `false` to disable.
    func enableBackgroundWorkoutsUpdates(enabled: Bool) async
}

extension HealthActivitiesPermission {

    public func isAuthorizationRequestNeeded(for type: HKObjectType) throws -> Bool {
        try HealthKitManager.shared.checkAuthorizationStatus(for: type)
    }
    
    public func statusForHealthKitAuthorizationRequest(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws {
        try await HealthKitManager.shared.statusForAuthorizationRequest(toWrite: toWrite ?? [], toRead: toRead ?? [])
    }
    
    // MARK: - Background Delivery Methods
    
    public func enableBackgroundWalkingActivityUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async {
        let manager = HealthKitManager.shared
        await manager.backgroundDeliveryForReadTypes(enable: enabled, types: toRead ?? manager.forWalkingActivityQuantityType)
    }
    
    public func enableBackgroundSleepActivityUpdates(enabled: Bool) async {
        let manager = HealthKitManager.shared
        await manager.backgroundDeliveryForSampleTypes(enable: enabled, types: manager.forSleepActivityCategoryType)
    }
    
    public func enableBackgroundMindfulActivityUpdates(enabled: Bool) async {
        let manager = HealthKitManager.shared
        await manager.backgroundDeliveryForSampleTypes(enable: enabled, types: manager.forMindfulActivityCategoryType)
    }
    
    public func enableBackgroundNutritionUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async {
        let manager = HealthKitManager.shared
        await manager.backgroundDeliveryForReadTypes(enable: enabled, types: toRead ?? manager.forDietaryNutritionQuantityType)
    }
    
    public func enableBackgroundHeartRateUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async {
        let manager = HealthKitManager.shared
        await manager.backgroundDeliveryForReadTypes(enable: enabled, types: toRead ?? manager.forHeartRateQuantityType)
    }
    
    public func enableBackgroundWorkoutsUpdates(enabled: Bool) async {
        let manager = HealthKitManager.shared
        await manager.backgroundDeliveryForSampleTypes(enable: enabled, types: manager.forWorkoutsSampleType)
    }
}
