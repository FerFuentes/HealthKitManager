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
        if start {
            guard mindfulActivityObserverQuery == nil else {
                return
            }
            
            let mindfulType = HKCategoryType(.mindfulSession)
            let query = HKObserverQuery(
                sampleType: mindfulType,
                predicate: nil) { [weak self] query, completionHandler, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        clearMindfulActivityObserverQuery()
                        debugPrint("Error observing mindful activity: \(error)")
                        completion(.failure(error))
                    } else {
                        Task {
                            do {
                                let activity = try await self.getMindfulActivity(date: Date())
                                completion(.success(activity))
                            } catch {
                                completion(.failure(error))
                            }
                        }
                    }
                    mindfulActivityCompletionHandler = completionHandler
                }
            
            healthStore.execute(query)
            mindfulActivityObserverQuery = query
        } else {
            if let query = mindfulActivityObserverQuery {
                healthStore.stop(query)
                clearMindfulActivityObserverQuery()
            }
        }
    }
    
    func clearMindfulActivityObserverQuery() {
        mindfulActivityCompletionHandler?()
        mindfulActivityObserverQuery = nil
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
            debugPrint("Error fetching mindful data: \(error.localizedDescription)")
        }
        
        return MindfulActivityData(mindfulSeconds: totalMindfulSeconds)
    }
}
