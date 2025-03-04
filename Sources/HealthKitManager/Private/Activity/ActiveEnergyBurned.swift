//
//  ActiveEnergyBurned.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 23/01/25.
//
import Foundation
import HealthKit

extension HealthKitManager {
    func getActiveEnergyBurned(date: Date) async throws -> Double? {
        let type = HKQuantityType(.activeEnergyBurned)
        _ = try checkAuthorizationStatus(for: type)
        
        guard let activeEnergyBurned = try await getDescriptor(
            date: date,
            type: type,
            options: .cumulativeSum
        ).result(for: healthStore)
            .statistics(for: date)?
            .sumQuantity()?
            .doubleValue(for: HKUnit.kilocalorie())
        else {
            return nil
        }
        
        return Double(String(format: "%.2f", activeEnergyBurned)) ?? 0.0
    }
}

