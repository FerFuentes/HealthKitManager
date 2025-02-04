//
//  Date+Extension.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 29/01/25.
//
import Foundation

extension Date {
    
    public func formattedTime(use24HourFormat: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: self)
    }
    
    public func formattedDate(with format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
    
    public func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        return formatter.string(from: self)
    }
}
