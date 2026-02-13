//
//  HKMMetrics.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/02/25.
//
import HealthKit

internal extension HealthKitManager {
    
    // MARK: - Observer Query for Background Delivery
    
    /// Starts or stops observing heart rate changes using HKObserverQuery.
    ///
    /// This method sets up a real-time observer for heart rate data changes including both
    /// instantaneous and resting heart rate. When new heart rate data is recorded, the completion
    /// handler is called with updated heart rate data.
    ///
    /// - Parameters:
    ///   - start: `true` to start observing, `false` to stop.
    ///   - completion: A closure called when heart rate data changes.
    ///                 Returns `Result<HeartRateData?, Error>`.
    ///
    /// - Note: Enable background delivery using `enableBackgroundHeartRateUpdates(enabled:)`
    ///         to receive updates when the app is in the background.
    func observeHeartRateQuery(
        _ start: Bool,
        completion: @escaping @Sendable (Result<HeartRateData?, Error>) -> Void
    ) {
        if start {
            guard heartRateObserverQuery == nil else {
                return
            }
            
            let excludeManualPredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
            let queryDescriptors = forHeartRateQuantityType.map { type in
                HKQueryDescriptor(sampleType: type, predicate: excludeManualPredicate)
            }
            
            let query = HKObserverQuery(
                queryDescriptors: queryDescriptors) { [weak self] query, updatedSampleTypes, completionHandler, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        clearHeartRateObserverQuery()
                        debugPrint("Error observing heart rate: \(error)")
                        completion(.failure(error))
                    } else {
                        Task {
                            let heartRate = await self.getHeartRate(date: Date(), sampleTypes: self.forHeartRateQuantityType)
                            completion(.success(heartRate))
                        }
                    }
                    heartRateCompletionHandler = completionHandler
                }
            
            healthStore.execute(query)
            heartRateObserverQuery = query
        } else {
            if let query = heartRateObserverQuery {
                healthStore.stop(query)
                clearHeartRateObserverQuery()
            }
        }
    }
    
    func clearHeartRateObserverQuery() {
        heartRateCompletionHandler?()
        heartRateObserverQuery = nil
    }
    
    // MARK: - Data Fetching Methods
    
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
                    debugPrint("Error fetching resting heart rate: \(error.localizedDescription)")
                }
            default:
                debugPrint("Unknown heart rate quantity type: \(quantityType)")
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
                    debugPrint("Error fetching height: \(error.localizedDescription)")
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
                    debugPrint("Error fetching body mass: \(error.localizedDescription)")
                }
            default:
                debugPrint("Unknown body metrics quantity type: \(quantityType)")
            }
        }
        
        return BodyData(
            height: height,
            weight: weight
        )
    }
}
