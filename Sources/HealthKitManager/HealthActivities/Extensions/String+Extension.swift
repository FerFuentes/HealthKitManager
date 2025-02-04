//
//  String+Extension.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 03/02/25.
//
import Foundation

extension String {
    
    public func toDate(with format: String)  -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        return dateFormatter.date(from: self)
    }
}
