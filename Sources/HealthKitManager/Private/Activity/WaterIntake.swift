//
//  HKMWaterActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import HealthKit

extension HealthKitManager {
    @MainActor
    func getWaterIntake(date: Date) async throws -> Double? {
        let type = HKQuantityType(.dietaryWater)
        _ = try checkAuthorizationStatus(for: type)
        
        guard let waterOncesCount = try await getDescriptor(
            date: date,
            type: type,
            options: .cumulativeSum,
            excludeManual: false
        ).result(for: healthStore)
            .statistics(for: date)?
            .sumQuantity()?
            .doubleValue(for: HKUnit.fluidOunceUS())
        else {
            return nil
        }
    
        return Double(String(format: "%.2f", waterOncesCount)) ?? 0.0
    }
}
