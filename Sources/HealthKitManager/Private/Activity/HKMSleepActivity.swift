//
//  HealthKitManager+SleepActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/02/25.
//
import HealthKit

extension HealthKitManager {
    
    private func getPredicateForSleep(date: Date) -> HKSamplePredicate<HKCategorySample> {
        let sleepSampleType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.date(byAdding: .hour, value: -9, to: calendar.startOfDay(for: date))!
        let endDate = calendar.date(byAdding: .hour, value: 15, to: calendar.startOfDay(for: date))!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        return HKSamplePredicate.categorySample(type: sleepSampleType, predicate: predicateForSamples)
    }
    
    private func getDescriptorForSleep(date: Date)  -> HKSampleQueryDescriptor<HKCategorySample> {
        let predicate = getPredicateForSleep(date: date)
        
        return HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }
    
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
