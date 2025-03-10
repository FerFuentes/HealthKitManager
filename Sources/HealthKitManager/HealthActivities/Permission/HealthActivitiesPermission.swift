//
//  Untitled.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import HealthKit

public protocol HealthActivitiesPermission {
    func statusForHealthKitAuthorizationRequest(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws
    func isAuthorizationRequestNeeded(for type: HKObjectType) throws -> Bool
    
    func enablebackgroundWalkingActivityUpdates(enabled: Bool) async
}

extension HealthActivitiesPermission {

    public func isAuthorizationRequestNeeded(for type: HKObjectType) throws -> Bool {
        try HealthKitManager.shared.checkAuthorizationStatus(for: type)
    }
    
    public func statusForHealthKitAuthorizationRequest(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws {
        try await HealthKitManager.shared.statusForAuthorizationRequest(toWrite: toWrite ?? [], toRead: toRead ?? [])
    }
    
    public func enablebackgroundWalkingActivityUpdates(enabled: Bool) async {
        let manager = HealthKitManager.shared
        return await manager.backgroundDeliveryForReadTypes(enable: enabled, types: manager.forWalkingActivityQuantityType)
    }
}
