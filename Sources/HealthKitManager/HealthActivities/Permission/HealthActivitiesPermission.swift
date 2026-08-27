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
///
/// - Important: Enabling background delivery never presents the permission sheet. Request
///   authorization first with `statusForHealthKitAuthorizationRequest(toWrite:toRead:)`
///   from a user-initiated flow; enabling before that throws
///   `Permission.Error.needToRequestPermission`, and the caller should enable again once
///   the user has granted access.
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
    ///
    /// The enabled types are also the ones the walking observer watches, so a type enabled
    /// here always has a handler to acknowledge its deliveries. They decide **what wakes the
    /// app**, not what a delivery reads: every delivery reads the whole walking payload, so
    /// narrowing these never narrows what gets posted.
    ///
    /// Enabling synchronises the store by difference: the requested types are enabled, and
    /// walking types that were enabled before and are not requested now are disabled. Without
    /// that, narrowing the set left the dropped types enabled with no observer descriptor to
    /// acknowledge them, and iOS spends three wake-ups on each before giving up.
    ///
    /// The previous set falls back to every walking type when nothing has been enabled in this
    /// process yet, and that fallback is load-bearing rather than a default: what a previous
    /// *version* of the app enabled outlives the process that enabled it, so a cold launch has
    /// to assume the widest set it could have been to clear it. Narrowing this to only what
    /// this process enabled would leave an upgraded device carrying the old set forever.
    ///
    /// - Important: The caller must have requested authorization for the whole walking
    ///   payload — steps, distance and calories — not only for the types it wakes on. A
    ///   delivery reads the payload regardless of what woke it, and HealthKit answers a read
    ///   it was never authorized for with no samples rather than an error, so the shortfall
    ///   would surface as permanently empty days rather than as a failure.
    ///
    /// - Parameters:
    ///   - enabled: `true` to enable, `false` to disable.
    ///   - toRead: Optional set of quantity types to wake on. Defaults to steps, heart rate,
    ///     distance and calories — every walking type, heart rate included, which wakes the
    ///     app far more often than a walking total changes. Callers that care about battery
    ///     should pass the one type their payload is accounted in.
    /// - Throws: `Permission.Error` when authorization is not established, or
    ///   ``BackgroundDeliveryError`` naming the types that could not be toggled.
    func setBackgroundWalkingActivityUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async throws

    /// Enables or disables background delivery for sleep activity updates.
    /// - Parameter enabled: `true` to enable, `false` to disable.
    /// - Throws: `Permission.Error` or ``BackgroundDeliveryError``.
    func setBackgroundSleepActivityUpdates(enabled: Bool) async throws

    /// Enables or disables background delivery for mindful activity updates.
    /// - Parameter enabled: `true` to enable, `false` to disable.
    /// - Throws: `Permission.Error` or ``BackgroundDeliveryError``.
    func setBackgroundMindfulActivityUpdates(enabled: Bool) async throws

    /// Enables or disables background delivery for nutrition updates.
    /// - Parameters:
    ///   - enabled: `true` to enable, `false` to disable.
    ///   - toRead: Optional set of quantity types. Defaults to calories, carbs, protein, and fat.
    /// - Throws: `Permission.Error` or ``BackgroundDeliveryError``.
    func setBackgroundNutritionUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async throws

    /// Enables or disables background delivery for heart rate updates.
    /// - Parameters:
    ///   - enabled: `true` to enable, `false` to disable.
    ///   - toRead: Optional set of quantity types. Defaults to heart rate and resting heart rate.
    /// - Throws: `Permission.Error` or ``BackgroundDeliveryError``.
    func setBackgroundHeartRateUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async throws

    /// Enables or disables background delivery for workout updates.
    /// - Parameter enabled: `true` to enable, `false` to disable.
    /// - Throws: `Permission.Error` or ``BackgroundDeliveryError``.
    func setBackgroundWorkoutsUpdates(enabled: Bool) async throws

    @available(*, deprecated, message: "Swallows failures; use setBackgroundWalkingActivityUpdates(enabled:toRead:) instead.")
    func enableBackgroundWalkingActivityUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async

    @available(*, deprecated, message: "Swallows failures; use setBackgroundSleepActivityUpdates(enabled:) instead.")
    func enableBackgroundSleepActivityUpdates(enabled: Bool) async

    @available(*, deprecated, message: "Swallows failures; use setBackgroundMindfulActivityUpdates(enabled:) instead.")
    func enableBackgroundMindfulActivityUpdates(enabled: Bool) async

    @available(*, deprecated, message: "Swallows failures; use setBackgroundNutritionUpdates(enabled:toRead:) instead.")
    func enableBackgroundNutritionUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async

    @available(*, deprecated, message: "Swallows failures; use setBackgroundHeartRateUpdates(enabled:toRead:) instead.")
    func enableBackgroundHeartRateUpdates(enabled: Bool, toRead: Set<HKQuantityType>?) async

    @available(*, deprecated, message: "Swallows failures; use setBackgroundWorkoutsUpdates(enabled:) instead.")
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

    public func setBackgroundWalkingActivityUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async throws {
        let manager = HealthKitManager.shared
        let types = toRead ?? HealthKitManager.forWalkingActivityQuantityType
        let previouslyEnabled = manager.walkingActivityBackgroundTypes

        try await manager.setBackgroundDelivery(enable: enabled, types: Set(types.map { $0 as HKSampleType }))

        let orphaned = enabled ? previouslyEnabled.subtracting(types) : []
        if !orphaned.isEmpty {
            try await manager.setBackgroundDelivery(enable: false, types: Set(orphaned.map { $0 as HKSampleType }))
        }

        manager.rememberWalkingActivityBackgroundTypes(enabled ? types : nil)
    }

    public func setBackgroundSleepActivityUpdates(enabled: Bool) async throws {
        let manager = HealthKitManager.shared
        try await manager.setBackgroundDelivery(enable: enabled, types: manager.forSleepActivityCategoryType)
    }

    public func setBackgroundMindfulActivityUpdates(enabled: Bool) async throws {
        let manager = HealthKitManager.shared
        try await manager.setBackgroundDelivery(enable: enabled, types: manager.forMindfulActivityCategoryType)
    }

    public func setBackgroundNutritionUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async throws {
        let manager = HealthKitManager.shared
        let types = toRead ?? manager.forDietaryNutritionQuantityType
        try await manager.setBackgroundDelivery(enable: enabled, types: Set(types.map { $0 as HKSampleType }))
    }

    public func setBackgroundHeartRateUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async throws {
        let manager = HealthKitManager.shared
        let types = toRead ?? manager.forHeartRateQuantityType
        try await manager.setBackgroundDelivery(enable: enabled, types: Set(types.map { $0 as HKSampleType }))
    }

    public func setBackgroundWorkoutsUpdates(enabled: Bool) async throws {
        let manager = HealthKitManager.shared
        try await manager.setBackgroundDelivery(enable: enabled, types: manager.forWorkoutsSampleType)
    }

    @available(*, deprecated, message: "Swallows failures; use setBackgroundWalkingActivityUpdates(enabled:toRead:) instead.")
    public func enableBackgroundWalkingActivityUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async {
        do {
            try await setBackgroundWalkingActivityUpdates(enabled: enabled, toRead: toRead)
        } catch {
            debugPrint("Error updating walking activity background delivery: \(error.localizedDescription)")
        }
    }

    @available(*, deprecated, message: "Swallows failures; use setBackgroundSleepActivityUpdates(enabled:) instead.")
    public func enableBackgroundSleepActivityUpdates(enabled: Bool) async {
        do {
            try await setBackgroundSleepActivityUpdates(enabled: enabled)
        } catch {
            debugPrint("Error updating sleep activity background delivery: \(error.localizedDescription)")
        }
    }

    @available(*, deprecated, message: "Swallows failures; use setBackgroundMindfulActivityUpdates(enabled:) instead.")
    public func enableBackgroundMindfulActivityUpdates(enabled: Bool) async {
        do {
            try await setBackgroundMindfulActivityUpdates(enabled: enabled)
        } catch {
            debugPrint("Error updating mindful activity background delivery: \(error.localizedDescription)")
        }
    }

    @available(*, deprecated, message: "Swallows failures; use setBackgroundNutritionUpdates(enabled:toRead:) instead.")
    public func enableBackgroundNutritionUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async {
        do {
            try await setBackgroundNutritionUpdates(enabled: enabled, toRead: toRead)
        } catch {
            debugPrint("Error updating nutrition background delivery: \(error.localizedDescription)")
        }
    }

    @available(*, deprecated, message: "Swallows failures; use setBackgroundHeartRateUpdates(enabled:toRead:) instead.")
    public func enableBackgroundHeartRateUpdates(enabled: Bool, toRead: Set<HKQuantityType>? = nil) async {
        do {
            try await setBackgroundHeartRateUpdates(enabled: enabled, toRead: toRead)
        } catch {
            debugPrint("Error updating heart rate background delivery: \(error.localizedDescription)")
        }
    }

    @available(*, deprecated, message: "Swallows failures; use setBackgroundWorkoutsUpdates(enabled:) instead.")
    public func enableBackgroundWorkoutsUpdates(enabled: Bool) async {
        do {
            try await setBackgroundWorkoutsUpdates(enabled: enabled)
        } catch {
            debugPrint("Error updating workouts background delivery: \(error.localizedDescription)")
        }
    }
}
