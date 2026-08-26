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
        observeQuery(
            start,
            coordinator: heartRateObservation,
            descriptors: { [weak self] in
                guard let self else { return [] }
                let excludeManual = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
                return self.forHeartRateQuantityType.map { HKQueryDescriptor(sampleType: $0, predicate: excludeManual) }
            },
            read: { [weak self] date in
                guard let self else { throw Permission.Error.unavailable }
                return try await self.getHeartRate(date: date, sampleTypes: self.forHeartRateQuantityType)
            },
            completion: completion
        )
    }
    
    // MARK: - Data Fetching Methods
    
    /// Reads the day's average and resting heart rate.
    ///
    /// - Parameters:
    ///   - date: The day to query.
    ///   - sampleTypes: The heart rate types to read.
    /// - Returns: The rates that could be read, with absent ones left `nil`.
    /// - Throws: The underlying failure when nothing could be read, so a broken read is
    ///   never reported as a day without a heartbeat.
    func getHeartRate(date: Date, sampleTypes: Set<HKSampleType>) async throws -> HeartRateData {
        var restingHeartRate: Double?
        var averageHeartRate: Double?
        var failures: [any Error] = []

        for sampleType in sampleTypes {
            guard let quantityType = sampleType as? HKQuantityType else {
                continue
            }

            do {
                switch quantityType {
                case HKQuantityType(.heartRate):
                    averageHeartRate = try await getAverageHeartRate(date: date)
                case HKQuantityType(.restingHeartRate):
                    restingHeartRate = try await getRestingHeartRate(date: date)
                default:
                    continue
                }
            } catch {
                failures.append(error)
            }
        }

        if let failure = PartialMetricRead.failureToSurface(readValues: [restingHeartRate, averageHeartRate], failures: failures) {
            throw failure
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
