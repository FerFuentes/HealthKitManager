//
//  WaterNutrition.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import Foundation

public protocol WaterNutrition {
    func getWaterIntakeInOnces(by date: Date) async throws -> Double?
}

extension WaterNutrition {
    public func getWaterIntakeInOnces(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getWaterIntake(date: date)
    }
}
