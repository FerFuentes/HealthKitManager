//
//  HKM Mindful.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import HealthKit

internal extension HealthKitManager {
    private func getPredicateForMindful(date: Date) -> HKSamplePredicate<HKCategorySample> {
        let mindfulSessionSampleType = HKCategoryType(.mindfulSession)
        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicateForSamples = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        return HKSamplePredicate.categorySample(type: mindfulSessionSampleType, predicate: predicateForSamples)
    }
    
    private func getDescriptorForMindful(date: Date)  -> HKSampleQueryDescriptor<HKCategorySample> {
        let predicate = getPredicateForMindful(date: date)
        
        return HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
    }
    
    func getMindfulActivity(date: Date) async throws -> MindfulActivityData {
        var totalMindfulSeconds: Double = 0
        
        let category = HKCategoryType(.mindfulSession)
        
        do {
            _ = try checkAuthorizationStatus(for: category)
            let sample = try await getDescriptorForMindful(date: date)
                .result(for: healthStore)
            
            for sample in sample {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                totalMindfulSeconds += duration
            }
        } catch {
            debugPrint("Error fetching heart rate: \(error.localizedDescription)")
        }
        
        return MindfulActivityData(mindfulSeconds: totalMindfulSeconds)
    }
}
