//
//  DietaryNutrition.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import Foundation

/// Protocol for accessing dietary nutrition data from HealthKit.
///
/// Conform to this protocol to access calories, macronutrients (protein, carbs, fat),
/// and water intake. Also supports real-time background observation.
public protocol DietaryNutrition {
    /// Gets water intake for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: Water intake in fluid ounces, or `nil` if unavailable.
    func getWaterIntakeInOnces(by date: Date) async throws -> Double?
    
    /// Gets complete dietary nutrition data for a specific date.
    /// - Parameter date: The date to query.
    /// - Returns: A `DietaryNutritionData` object with calories and macros.
    func getDietaryNutritionData(by date: Date) async throws -> DietaryNutritionData
    
    /// Starts or stops observing nutrition data changes in the background.
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: Called when nutrition data changes.
    func observeNutritionInBackground(_ start: Bool, completion: @escaping @Sendable (Result<DietaryNutritionData?, Error>) -> Void)
}

extension DietaryNutrition {
    public func getWaterIntakeInOnces(by date: Date) async throws -> Double? {
        try await HealthKitManager.shared.getWaterIntake(date: date)
    }
    
    public func getDietaryNutritionData(by date: Date) async throws -> DietaryNutritionData {
        let manager = HealthKitManager.shared
        return try await manager.getDietaryNutrition(date: date, sampleTypes: manager.forDietaryNutritionQuantityType)
    }
    
    public func observeNutritionInBackground(_ start: Bool, completion: @escaping @Sendable (Result<DietaryNutritionData?, Error>) -> Void) {
        HealthKitManager.shared.observeNutritionQuery(start, completion: completion)
    }
}
