//
//  HKMSleepActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/02/25.
//
import HealthKit

internal extension HealthKitManager {
    
    // MARK: - Observer Query for Background Delivery
    
    /// Starts or stops observing sleep activity changes using HKObserverQuery.
    ///
    /// This method sets up a real-time observer for sleep analysis changes. When new sleep data
    /// is recorded, the completion handler is called with updated sleep activity data.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when sleep activity data changes.
    ///                 Returns `Result<SleepActivityData?, Error>`.
    ///
    /// - Note: Enable background delivery using `enableBackgroundSleepActivityUpdates(enabled:)`
    ///         to receive updates when the app is in the background.
    func observeSleepActivityQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<SleepActivityData?, Error>) -> Void
    ) {
        if start {
            guard sleepActivityObserverQuery == nil else {
                return
            }
            
            let sleepType = HKCategoryType(.sleepAnalysis)
            let query = HKObserverQuery(
                sampleType: sleepType,
                predicate: nil) { [weak self] _, completionHandler, error in
                    nonisolated(unsafe) let acknowledgeDelivery = completionHandler

                    guard let self = self else {
                        acknowledgeDelivery()
                        return
                    }

                    if let error = error {
                        acknowledgeDelivery()
                        self.stopSleepActivityObserver()
                        completion(.failure(error))
                    } else {
                        Task {
                            await HealthKitDeliveryProcessor.processDelivery(
                                dates: [Date()],
                                read: { date in try await self.getSleepActivity(date: date) },
                                report: completion,
                                acknowledge: { acknowledgeDelivery() }
                            )
                        }
                    }
                }
            
            healthStore.execute(query)
            sleepActivityObserverQuery = query
        } else {
            stopSleepActivityObserver()
        }
    }
    
    /// Stops and releases the active sleep observer query.
    func stopSleepActivityObserver() {
        guard let query = sleepActivityObserverQuery else { return }
        healthStore.stop(query)
        sleepActivityObserverQuery = nil
    }
    
    // MARK: - Predicates and Descriptors
    
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
            debugPrint("Error fetching sleep data: \(error.localizedDescription)")
        }
        
        return SleepActivityData(
            awakeTimes: awakeTimes,
            asleepREMInSeconds: asleepREMSeconds,
            asleepCorepSeconds: asleepCorepSeconds,
            deepSleepSeconds: deepSleepSeconds
        )
    }
}
