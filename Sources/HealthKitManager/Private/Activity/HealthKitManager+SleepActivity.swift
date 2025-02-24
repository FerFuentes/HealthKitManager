//
//  HealthKitManager+SleepActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/02/25.
//
import HealthKit

extension HealthKitManager {
    
    func getSleepActivity(date: Date) async throws -> SleepActivityData {
        var awakeTimes: Int = 0
        var asleepREMSeconds: Double = 0
        var asleepCorepSeconds: Double = 0
        var deepSleepSeconds: Double = 0
        
        let category = HKCategoryType(.sleepAnalysis)
        
        do {
            _ = try checkAuthorizationStatus(for: category)
            let sample = try await getDescriptorForSleep(date: date)
                .result(for: healthStore)
            
            for sample in sample {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    asleepREMSeconds += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    asleepCorepSeconds += duration
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepSleepSeconds += duration
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    awakeTimes += 1
                default:
                    break
                }
            }
        } catch {
            debugPrint("Error fetching heart rate: \(error.localizedDescription)")
        }
        
        return SleepActivityData(
            awakeTimes: awakeTimes,
            asleepREMInSeconds: asleepREMSeconds,
            asleepCorepSeconds: asleepCorepSeconds,
            deepSleepSeconds: deepSleepSeconds
        )
    }
}
