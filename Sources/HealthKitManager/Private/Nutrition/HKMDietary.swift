//
//  DietaryStats.swift
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
    
    func getDietaryNutrition(date: Date, sampleTypes: Set<HKSampleType>) async -> DietaryNutritionData {
        var calories: Double?
        var carbohydrates: Double?
        var protein: Double?
        var fat: Double?
        
        for sampleType in sampleTypes {
            guard let quantityType = sampleType as? HKQuantityType else {
                continue
            }
            switch quantityType {
                
            case HKQuantityType(.dietaryEnergyConsumed):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    calories = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .cumulativeSum,
                        excludeManual: false
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.kilocalorie())
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.dietaryFatTotal):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    fat = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .cumulativeSum,
                        excludeManual: false
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.gram())
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.dietaryCarbohydrates):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    carbohydrates = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .cumulativeSum,
                        excludeManual: false
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.gram())
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.dietaryProtein):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    protein = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .cumulativeSum,
                        excludeManual: false
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .sumQuantity()?
                        .doubleValue(for: HKUnit.gram())
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
            default:
                print("Unknown quantity type")
            }
        }
        
        return DietaryNutritionData(
            caloriesKcal: calories,
            carbohydratesGrams: carbohydrates,
            proteinGrams: protein,
            fatGrams: fat
        )
    }
}
