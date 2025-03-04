//
//  StepsDistance.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 23/01/25.
//
import HealthKit

extension HealthKitManager {
    func getDistanceWalkingRunning(date: Date, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType(.distanceWalkingRunning)
        _ = try checkAuthorizationStatus(for: type)
        
        guard let distanceWalkingRunning = try await getDescriptor(
            date: date,
            type: type,
            options: .cumulativeSum
        ).result(for: healthStore)
            .statistics(for: date)?
            .sumQuantity()?
            .doubleValue(for: unit)
        else {
            return nil
        }
        
        return Double(String(format: "%.2f", distanceWalkingRunning)) ?? 0.0
    }
}
