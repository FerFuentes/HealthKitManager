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
        observeQuery(
            start,
            coordinator: nutritionObservation,
            descriptors: { [weak self] in
                guard let self else { return [] }
                let excludeManual = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
                return self.forDietaryNutritionQuantityType.map { HKQueryDescriptor(sampleType: $0, predicate: excludeManual) }
            },
            read: { [weak self] date in
                guard let self else { throw Permission.Error.unavailable }
                return try await self.getDietaryNutrition(date: date, sampleTypes: self.forDietaryNutritionQuantityType)
            },
            completion: completion
        )
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
    
    /// Reads the day's dietary totals for the requested nutrients.
    ///
    /// - Parameters:
    ///   - date: The day to query.
    ///   - sampleTypes: The nutrient types to read.
    /// - Returns: The nutrients that could be read, with absent ones left `nil`.
    /// - Throws: The underlying failure when nothing could be read, so a broken read is
    ///   never reported as a day without food.
    func getDietaryNutrition(date: Date, sampleTypes: Set<HKSampleType>) async throws -> DietaryNutritionData {
        var calories: Double?
        var carbohydrates: Double?
        var protein: Double?
        var fat: Double?
        var failures: [any Error] = []

        for sampleType in sampleTypes {
            guard let quantityType = sampleType as? HKQuantityType else {
                continue
            }

            let unit: HKUnit
            switch quantityType {
            case HKQuantityType(.dietaryEnergyConsumed):
                unit = .kilocalorie()
            case HKQuantityType(.dietaryFatTotal), HKQuantityType(.dietaryCarbohydrates), HKQuantityType(.dietaryProtein):
                unit = .gram()
            default:
                continue
            }

            do {
                let total = try await readDietaryTotal(date: date, type: quantityType, unit: unit)
                switch quantityType {
                case HKQuantityType(.dietaryEnergyConsumed):
                    calories = total
                case HKQuantityType(.dietaryFatTotal):
                    fat = total
                case HKQuantityType(.dietaryCarbohydrates):
                    carbohydrates = total
                default:
                    protein = total
                }
            } catch {
                failures.append(error)
            }
        }

        if let failure = PartialMetricRead.failureToSurface(readValues: [calories, carbohydrates, protein, fat], failures: failures) {
            throw failure
        }

        return DietaryNutritionData(
            caloriesKcal: calories,
            carbohydratesGrams: carbohydrates,
            proteinGrams: protein,
            fatGrams: fat
        )
    }

    /// Reads one nutrient's daily total, including manually entered samples.
    private func readDietaryTotal(date: Date, type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        _ = try checkAuthorizationStatus(for: type)
        return try await getDescriptor(
            date: date,
            type: type,
            options: .cumulativeSum,
            excludeManual: false
        ).result(for: healthStore)
            .statistics(for: date)?
            .sumQuantity()?
            .doubleValue(for: unit)
    }

}
