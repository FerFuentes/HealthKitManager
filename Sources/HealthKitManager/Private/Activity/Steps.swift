//
//  Steps.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 23/01/25.
//
import HealthKit

internal extension HealthKitManager {
    func getStepCount(date: Date) async throws -> Double? {
        let type = HKQuantityType(.stepCount)
        _ = try checkAuthorizationStatus(for: type)
        
        guard let stepCount = try await getDescriptor(
            date: date,
            type: type,
            options: .cumulativeSum
        ).result(for: healthStore)
            .statistics(for: date)?
            .sumQuantity()?
            .doubleValue(for: HKUnit.count())
        else {
            return nil
        }
    
        return stepCount
    }
}
