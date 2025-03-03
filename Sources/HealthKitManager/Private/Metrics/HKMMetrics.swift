//
//  HKMHeartRate.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/02/25.
//
import HealthKit

extension HealthKitManager {
    func getHeartRate(date: Date, sampleTypes: Set<HKSampleType>) async -> HeartRateData {
        var restingHeartRate: Double?
        var averageHeartRate: Double?
        
        for sampleType in sampleTypes {
            guard let quantityType = sampleType as? HKQuantityType else {
                continue
            }
            switch quantityType {
                
            case HKQuantityType(.heartRate):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    averageHeartRate = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .discreteAverage
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .averageQuantity()?
                        .doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.restingHeartRate):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    
                    restingHeartRate = try await getDescriptor(
                        date: date,
                        type: quantityType,
                        options: .discreteAverage
                    ).result(for: healthStore)
                        .statistics(for: date)?
                        .averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))

                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
            default:
                print("Unknown quantity type")
            }
        }
        
        return HeartRateData(
            restingHeartRate: restingHeartRate,
            averageHeartRate: averageHeartRate
        )
    }
    
    private func getDescriptorForBodyMetrics(date: Date, type: HKQuantityType)  -> HKSampleQueryDescriptor<HKQuantitySample> {
        let predicate = HKSamplePredicate.quantitySample(type: type)
        
        return HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: []
        )
    }

    
    func getBodyMetrics(date: Date, sampleTypes: Set<HKSampleType>) async -> BodyData {
        var height: Double?
        var weight: Double?
        
        for sampleType in sampleTypes {
            guard let quantityType = sampleType as? HKQuantityType else {
                continue
            }
            switch quantityType {
                
            case HKQuantityType(.height):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    height = try await getDescriptorForBodyMetrics(
                        date: date,
                        type: quantityType
                    ).result(for: healthStore)
                        .last?
                        .quantity
                        .doubleValue(for: HKUnit.meterUnit(with: .centi))
                    
                    
                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
                
            case HKQuantityType(.bodyMass):
                do {
                    _ = try checkAuthorizationStatus(for: quantityType)
                    
                    weight = try await getDescriptorForBodyMetrics(
                        date: date,
                        type: quantityType
                    ).result(for: healthStore)
                        .last?
                        .quantity
                        .doubleValue(for: HKUnit.gramUnit(with: .kilo))

                } catch {
                    debugPrint("Error fetching heart rate: \(error.localizedDescription)")
                }
            default:
                print("Unknown quantity type")
            }
        }
        
        return BodyData(
            height: height,
            weight: weight
        )
    }
}
