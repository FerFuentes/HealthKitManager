//
//  WorkoutMetadata.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes on 29/01/25.
//
import Foundation
import HealthKit

internal struct WorkoutMetadata {
    let averageMETs: Double?
    let indoorWorkout: Bool?
    let timeZone: String?
    let humidity: Double?
    let temperature: Double?
    
    // Inicializador para convertir un diccionario en un objeto
    init(from dictionary: [String: Any]?) {
        self.averageMETs = (dictionary?[HKMetadataKeyAverageMETs] as? HKQuantity)?.doubleValue(for: HKUnit.init(from: "kcal/(kg*hr)"))
        self.indoorWorkout = dictionary?[HKMetadataKeyIndoorWorkout] as? Bool
        self.timeZone = dictionary?[HKMetadataKeyTimeZone] as? String
        self.humidity = (dictionary?[HKMetadataKeyWeatherHumidity] as? HKQuantity)?.doubleValue(for: HKUnit.percent())
        self.temperature = (dictionary?[HKMetadataKeyWeatherTemperature] as? HKQuantity)?.doubleValue(for: HKUnit.degreeFahrenheit())
    }
}
