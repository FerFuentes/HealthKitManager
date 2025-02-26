//
//  Nutrition.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import Foundation

public protocol DietaryNutrition {
    func getWaterIntakeInOnces(by date: Date) async throws -> Double?
    func getDietaryNutritionData(by date: Date) async throws -> DietaryNutritionData
}

extension DietaryNutrition {
    public func getWaterIntakeInOnces(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getWaterIntake(date: date)
    }
    
    public func getDietaryNutritionData(by date: Date) async -> DietaryNutritionData {
        let manager = HealthKitManager.shared
        return await HealthKitManager.shared.getDietaryNutrition(date: date, sampleTypes: manager.forDietaryNutritionQuantityType)
    }
}
