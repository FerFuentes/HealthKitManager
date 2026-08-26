//
//  BackgroundDeliveryError.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 26/08/26.
//

import Foundation
import HealthKit

/// Reports the types whose background delivery could not be toggled.
///
/// Toggling is attempted for every requested type, so the types absent from
/// ``failedTypeIdentifiers`` were switched successfully and the ones listed kept their
/// previous state.
public struct BackgroundDeliveryError: Error {
    public let failedTypeIdentifiers: [String]
    public let underlying: [any Error]

    /// - Parameter failures: The type and error of every toggle that failed.
    /// - Returns: `nil` when every type was toggled successfully.
    init?(failures: [(type: HKSampleType, error: any Error)]) {
        guard !failures.isEmpty else { return nil }
        self.failedTypeIdentifiers = failures.map { $0.type.identifier }
        self.underlying = failures.map(\.error)
    }
}

extension BackgroundDeliveryError: LocalizedError {
    public var errorDescription: String? {
        "Background delivery could not be changed for: \(failedTypeIdentifiers.joined(separator: ", "))."
    }
}
