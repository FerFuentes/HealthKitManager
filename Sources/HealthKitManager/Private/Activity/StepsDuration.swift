//
//  StepsDuration.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 23/01/25.
//
import HealthKit

extension HealthKitManager {
    func getTotalDurationInMinutes(date: Date) async throws -> Double {
        let type = HKQuantityType(.stepCount)
        _ = try checkAuthorizationStatus(for: type)
        
        var totalDuration: Double = 0.0
        let predicate = getPredicate(date: date)
        
        let totalDurationDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        
        let stepSamples = try await totalDurationDescriptor.result(for: healthStore)
        totalDuration += stepSamples
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60.0
    
        return Double(String(format: "%.2f", totalDuration)) ?? 0.0
    }
}
