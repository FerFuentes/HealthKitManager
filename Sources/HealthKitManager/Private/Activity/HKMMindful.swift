//
//  HKMMindful.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import HealthKit

internal extension HealthKitManager {
    
    // MARK: - Observer Query for Background Delivery
    
    /// Starts or stops observing mindful activity changes using HKObserverQuery.
    ///
    /// This method sets up a real-time observer for mindfulness session changes. When new mindful
    /// sessions are recorded, the completion handler is called with updated mindful activity data.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when mindful activity data changes.
    ///                 Returns `Result<MindfulActivityData?, Error>`.
    ///
    /// - Note: Enable background delivery using `enableBackgroundMindfulActivityUpdates(enabled:)`
    ///         to receive updates when the app is in the background.
    func observeMindfulActivityQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<MindfulActivityData?, Error>) -> Void
    ) {
        observeQuery(
            start,
            coordinator: mindfulActivityObservation,
            descriptors: { [HKQueryDescriptor(sampleType: HKCategoryType(.mindfulSession), predicate: nil)] },
            read: { [weak self] date in
                guard let self else { throw Permission.Error.unavailable }
                return try await self.getMindfulActivity(date: date)
            },
            completion: completion
        )
    }
    
    // MARK: - Predicates and Descriptors
    
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
    
    /// Reads the total mindful time for a date.
    ///
    /// - Parameter date: The day to query.
    /// - Returns: The seconds spent in mindful sessions.
    /// - Throws: A `Permission.Error` or `HKError` when the samples cannot be read; the
    ///   read never reports zero seconds for a failure.
    func getMindfulActivity(date: Date) async throws -> MindfulActivityData {
        var totalMindfulSeconds: Double = 0
        
        let category = HKCategoryType(.mindfulSession)
        _ = try checkAuthorizationStatus(for: category)

        let samples = try await getDescriptorForMindful(date: date).result(for: healthStore)

        for sample in samples {
            totalMindfulSeconds += sample.endDate.timeIntervalSince(sample.startDate)
        }
        
        return MindfulActivityData(mindfulSeconds: totalMindfulSeconds)
    }

}
