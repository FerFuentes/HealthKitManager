//
//  HeartRateMetrics.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/02/25.
//
import Foundation

public protocol Metrics {
    func getHeartRateMetrics(by date: Date) async -> HeartRateData
}

extension Metrics {
    public func getHeartRateMetrics(by date: Date) async -> HeartRateData {
        let manager = HealthKitManager.shared
        return await HealthKitManager.shared.getHeartRate(date: date, sampleTypes: manager.forHeartRateQuantityType)
    }
}
