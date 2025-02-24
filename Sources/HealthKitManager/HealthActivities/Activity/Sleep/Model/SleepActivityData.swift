//
//  SleepActivityData.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/02/25.
//
import Foundation

public struct SleepActivityData: @unchecked Sendable, Codable {
    public let awakeTimes: Int?
    public let asleepREMInSeconds: Double?
    public let asleepCorepSeconds: Double?
    public let deepSleepSeconds: Double?
}
