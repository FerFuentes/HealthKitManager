//
//  HealthKitManagerTests.swift
//  HealthKitManager
//
//  Created by Fernando Fuentes.
//

import Testing
import HealthKit
@testable import HealthKitManager

/// Tests for HealthKitManager data models.
struct HealthKitManagerTests {
    
    // MARK: - WalkingActivityData Tests
    
    @Test func walkingActivityDataInitialization() {
        let date = Date()
        let data = WalkingActivityData(
            date: date,
            steps: 10000,
            activeCalories: 500,
            distanceMeters: 8000,
            durationMinutes: 120,
            averageHeartRate: 85
        )
        
        #expect(data.steps == 10000)
        #expect(data.activeCalories == 500)
        #expect(data.distanceMeters == 8000)
        #expect(data.durationMinutes == 120)
        #expect(data.averageHeartRate == 85)
    }
    
    @Test func walkingActivityDataWithNilValues() {
        let date = Date()
        let data = WalkingActivityData(
            date: date,
            steps: nil,
            activeCalories: nil,
            distanceMeters: nil,
            durationMinutes: nil,
            averageHeartRate: nil
        )
        
        #expect(data.steps == nil)
        #expect(data.activeCalories == nil)
    }
    
    // MARK: - SleepActivityData Tests
    
    @Test func sleepActivityDataInitialization() {
        let data = SleepActivityData(
            awakeTimes: 3,
            asleepREMInSeconds: 5400,
            asleepCorepSeconds: 14400,
            deepSleepSeconds: 7200
        )
        
        #expect(data.awakeTimes == 3)
        #expect(data.asleepREMInSeconds == 5400)
        #expect(data.asleepCorepSeconds == 14400)
        #expect(data.deepSleepSeconds == 7200)
    }
    
    // MARK: - MindfulActivityData Tests
    
    @Test func mindfulActivityDataInitialization() {
        let data = MindfulActivityData(mindfulSeconds: 600)
        
        #expect(data.mindfulSeconds == 600)
    }
    
    // MARK: - DietaryNutritionData Tests
    
    @Test func dietaryNutritionDataInitialization() {
        let data = DietaryNutritionData(
            caloriesKcal: 2000,
            carbohydratesGrams: 250,
            proteinGrams: 100,
            fatGrams: 80
        )
        
        #expect(data.caloriesKcal == 2000)
        #expect(data.carbohydratesGrams == 250)
        #expect(data.proteinGrams == 100)
        #expect(data.fatGrams == 80)
    }
    
    // MARK: - HeartRateData Tests
    
    @Test func heartRateDataInitialization() {
        let data = HeartRateData(
            restingHeartRate: 60,
            averageHeartRate: 75
        )
        
        #expect(data.restingHeartRate == 60)
        #expect(data.averageHeartRate == 75)
    }
    
    // MARK: - BodyData Tests
    
    @Test func bodyDataInitialization() {
        let data = BodyData(
            height: 175,
            weight: 70
        )
        
        #expect(data.height == 175)
        #expect(data.weight == 70)
    }
    
    // MARK: - Permission Error Tests
    
    @Test func permissionErrorDescriptions() {
        let unavailableError = Permission.Error.unavailable
        let needPermissionError = Permission.Error.needToRequestPermission
        let invalidParamsError = Permission.Error.invalidParameters("Test message")
        
        #expect(unavailableError.errorDescription?.contains("HealthKit") == true)
        #expect(needPermissionError.errorDescription?.contains("Permission") == true)
        #expect(invalidParamsError.errorDescription?.contains("Test message") == true)
    }
}
