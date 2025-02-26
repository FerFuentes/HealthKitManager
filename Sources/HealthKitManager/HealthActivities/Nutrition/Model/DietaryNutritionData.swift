//
//  NutritionData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import Foundation

public struct DietaryNutritionData: Codable {
    public let caloriesKcal: Double?
    public let carbohydratesGrams: Double?
    public let proteinGrams: Double?
    public let fatGrams: Double?
}
