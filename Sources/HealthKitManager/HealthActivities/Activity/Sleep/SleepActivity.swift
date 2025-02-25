//
//  SleepActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 24/02/25.
//

import Foundation

public protocol SleepActivity {
    func getSleepActivityData(by date: Date) async throws -> SleepActivityData
}

extension SleepActivity {
    public func getSleepActivityData(by date: Date) async throws -> SleepActivityData {
        try await HealthKitManager.shared.getSleepActivity(date: date)
    }
}
