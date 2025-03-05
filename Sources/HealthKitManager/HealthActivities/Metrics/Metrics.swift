//
//  HeartRateMetrics.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/02/25.
//
import Foundation

public protocol Metrics {
    func getHeartRateMetrics(by date: Date) async -> HeartRateData
    func getBodyMetrics(by date: Date) async -> BodyData
}

extension Metrics {
    public func getHeartRateMetrics(by date: Date) async -> HeartRateData {
        let manager = HealthKitManager.shared
        return await manager.getHeartRate(date: date, sampleTypes: manager.forHeartRateQuantityType)
    }
    
    public func getBodyMetrics(by date: Date) async -> BodyData {
        let manager = HealthKitManager.shared
        return await manager.getBodyMetrics(date: date, sampleTypes: manager.forBodyMetricsQuantityType)
    }
}
