//
//  HKMDietary.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import HealthKit

internal extension HealthKitManager {
    
    // MARK: - Observer Query for Background Delivery
    
    /// Starts or stops observing nutrition data changes using HKObserverQuery.
    ///
    /// This method sets up a real-time observer for dietary nutrition changes including calories,
    /// protein, carbohydrates, and fat. When new nutrition data is recorded, the completion handler
    /// is called with updated dietary nutrition data.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when nutrition data changes.
    ///                 Returns `Result<DietaryNutritionData?, Error>`.
    ///
    /// - Note: Enable background delivery using `enableBackgroundNutritionUpdates(enabled:)`
    ///         to receive updates when the app is in the background.
    func observeNutritionQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<DietaryNutritionData?, Error>) -> Void
    ) {
        if start {
            guard nutritionObserverQuery == nil else {
                return
            }
            
            let excludeManualPredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
            let queryDescriptors = forDietaryNutritionQuantityType.map { type in
                HKQueryDescriptor(sampleType: type, predicate: excludeManualPredicate)
            }
            
            let query = HKObserverQuery(
                queryDescriptors: queryDescriptors) { [weak self] _, _, completionHandler, error in
                    nonisolated(unsafe) let acknowledgeDelivery = completionHandler

                    guard let self = self else {
                        acknowledgeDelivery()
                        return
                    }

                    if let error = error {
                        acknowledgeDelivery()
                        self.stopNutritionObserver()
                        completion(.failure(error))
                    } else {
                        Task {
                            await HealthKitDeliveryProcessor.processDelivery(
                                dates: [Date()],
                                read: { date in await self.getDietaryNutrition(date: date, sampleTypes: self.forDietaryNutritionQuantityType) },
                                report: completion,
                                acknowledge: { acknowledgeDelivery() }
                            )
                        }
                    }
                }
            
            healthStore.execute(query)
            nutritionObserverQuery = query
        } else {
            stopNutritionObserver()
        }
    }
    
    /// Stops and releases the active nutrition observer query.
    func stopNutritionObserver() {
        guard let query = nutritionObserverQuery else { return }
        healthStore.stop(query)
        nutritionObserverQuery = nil
    }
    
    // MARK: - Data Fetching Methods
    
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
                    debugPrint("Error fetching dietary energy: \(error.localizedDescription)")
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
                    debugPrint("Error fetching dietary fat: \(error.localizedDescription)")
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
                    debugPrint("Error fetching dietary carbohydrates: \(error.localizedDescription)")
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
                    debugPrint("Error fetching dietary protein: \(error.localizedDescription)")
                }
            default:
                debugPrint("Unknown dietary quantity type: \(quantityType)")
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
