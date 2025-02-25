//
//  MindfulActivity.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 25/02/25.
//
import Foundation

public protocol MindfulActivity {
    func getMindfulActivityData(by date: Date) async throws -> MindfulActivityData
}

extension MindfulActivity {
    public func getMindfulActivityData(by date: Date) async throws -> MindfulActivityData {
        try await HealthKitManager.shared.getMindfulActivity(date: date)
    }
}
