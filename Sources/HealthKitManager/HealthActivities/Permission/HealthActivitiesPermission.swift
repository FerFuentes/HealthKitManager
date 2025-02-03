//
//  Untitled.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import HealthKit

public protocol HealthActivitiesPermission {
    func statusForHealthKitAuthorizationRequest(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws
    
    func enablebackgroundWalkingActivityUpdates(enabled: Bool) async
}

extension HealthActivitiesPermission {
    
    public func statusForHealthKitAuthorizationRequest(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws {
        try await HealthKitManager.shared.statusForAuthorizationRequest(toWrite: toWrite ?? [], toRead: toRead ?? [])
    }
    
    public func enablebackgroundWalkingActivityUpdates(enabled: Bool) async {
        let manager = HealthKitManager.shared
        return await manager.bacgroundDelivery(enable: enabled, types: manager.forWalkingActivityQuantityType)
    }
}
