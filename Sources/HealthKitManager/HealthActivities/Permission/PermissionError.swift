//
//  PermissionError.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 15/01/25.
//

import Foundation

public enum Permission {
    public enum Error: Swift.Error, LocalizedError {
        case invalidParameters(String)
        case needToRequestPermission
        case unavailable
        case unknown(Swift.Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidParameters(let message):
                return "Invalid parameters: \(message)"
            case .unavailable:
                return "HealthKit is not available on this device."
            case .unknown(let error):
                return "An unknown error occurred: \(error.localizedDescription)"
            case .needToRequestPermission:
                return "Permission is required for this type before attempting to access it."
            }
        }
    }
}
