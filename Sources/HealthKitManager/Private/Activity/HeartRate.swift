//
//  HeartRate.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 23/01/25.
//
import Foundation
import HealthKit

internal extension HealthKitManager {
    func getAverageHeartRate(date: Date) async throws -> Double? {
        let type = HKQuantityType(.heartRate)
        _ = try checkAuthorizationStatus(for: type)
        
        guard let heartRate = try await getDescriptor(
            date: date,
            type: type,
            options: .discreteAverage
        ).result(for: healthStore)
            .statistics(for: date)?
            .averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        else {
            return nil
        }
        
        return Double(String(format: "%.2f", heartRate)) ?? 0.0
    }

    func getRestingHeartRate(date: Date) async throws -> Double? {
        let type = HKQuantityType(.restingHeartRate)
        _ = try checkAuthorizationStatus(for: type)
        
        guard let heartRate = try await getDescriptor(
            date: date,
            type: type,
            options: .discreteAverage
        ).result(for: healthStore)
            .statistics(for: date)?
            .averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
        else {
            return nil
        }
        
        return Double(String(format: "%.2f", heartRate)) ?? 0.0
    }
}
