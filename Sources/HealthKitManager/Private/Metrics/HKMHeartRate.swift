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
}
