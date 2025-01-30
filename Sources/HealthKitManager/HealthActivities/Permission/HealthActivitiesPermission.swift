//
//  Untitled.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import HealthKit

public protocol HealthActivitiesPermission {
    func requestHealthKitAuthorization(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws
}

extension HealthActivitiesPermission {
    
    public func requestHealthKitAuthorization(toWrite: Set<HKSampleType>?, toRead: Set<HKObjectType>?) async throws {
        try await HealthKitManager.shared.requestAuthorization(toWrite: toWrite ?? [], toRead: toRead ?? [])
    }
}
