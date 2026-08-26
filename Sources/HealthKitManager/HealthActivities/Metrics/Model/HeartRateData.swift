//
//  HeartRateData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/02/25.
//
import Foundation

public struct HeartRateData: Sendable, Codable {
    public let restingHeartRate: Double?
    public let averageHeartRate: Double?
}
