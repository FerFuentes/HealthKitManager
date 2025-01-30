//
//  Double+Extensions.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 29/01/25.
//
import Foundation

extension Double {
    public func toTimeString() -> String {
        let totalSeconds = Int(self * 60) // Convert minutes to seconds
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    public func roundedToString(toDecimalPlaces places: Int) -> String {
        let roundedValue = self.rounded(toDecimalPlaces: places)
        return String(format: "%.\(places)f", roundedValue)
    }
    
    public func rounded(toDecimalPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
