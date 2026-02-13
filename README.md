# HealthKitManager

A Swift package for easy integration with Apple HealthKit. Provides a clean protocol-based API to access health data including walking activities, sleep, mindfulness, nutrition, metrics, and workouts.

## Requirements

- iOS 16.0+ / watchOS 9.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/HealthKitManager.git", from: "1.0.0")
]
```

Or add it directly in Xcode via **File > Add Packages**.

## Setup

### 1. Add HealthKit Capability

In your Xcode project:
1. Select your target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **HealthKit**
5. Enable **Background Delivery** if you need background updates

### 2. Add Privacy Descriptions

Add the following keys to your `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>We need access to your health data to display your activity.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We need access to update your health data.</string>
```

## Usage

### Conforming to Protocols

Create a class or struct that conforms to the health protocols you need:

```swift
import HealthKitManager
import HealthKit

class HealthService: WalkingActivity, SleepActivity, MindfulActivity, 
                     DietaryNutrition, Metrics, WorkoutsActivity, 
                     HealthActivitiesPermission {
    // All methods have default implementations via protocol extensions
}
```

### Requesting Permissions

```swift
let healthService = HealthService()

// Request authorization for specific types
let readTypes: Set<HKObjectType> = [
    HKQuantityType(.stepCount),
    HKQuantityType(.heartRate),
    HKCategoryType(.sleepAnalysis)
]

try await healthService.statusForHealthKitAuthorizationRequest(
    toWrite: nil,
    toRead: readTypes
)
```

## Features

### Walking Activity

```swift
// Get step count for today
let steps = try await healthService.getStepsCount(by: Date())

// Get walking distance
let distance = try await healthService.getDistanceByWalkingAndRunning(
    by: Date(), 
    unit: .meter()
)

// Get calories burned
let calories = try await healthService.getCaloriesBurned(by: Date())

// Get complete walking activity data
let walkingData = await healthService.getWalkingActivityData(
    by: Date(),
    sampleTypes: [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate)
    ]
)
```

### Sleep Activity

```swift
// Get sleep data for a specific date
let sleepData = try await healthService.getSleepActivityData(by: Date())

print("REM Sleep: \(sleepData.asleepREMInSeconds) seconds")
print("Deep Sleep: \(sleepData.deepSleepSeconds) seconds")
print("Core Sleep: \(sleepData.asleepCorepSeconds) seconds")
print("Times Awake: \(sleepData.awakeTimes)")
```

### Mindful Activity

```swift
// Get mindfulness session data
let mindfulData = try await healthService.getMindfulActivityData(by: Date())

print("Mindful Minutes: \(mindfulData.mindfulSeconds / 60)")
```

### Nutrition

```swift
// Get water intake in fluid ounces
let waterOunces = try await healthService.getWaterIntakeInOnces(by: Date())

// Get dietary nutrition data
let nutritionData = await healthService.getDietaryNutritionData(by: Date())

print("Calories: \(nutritionData.caloriesKcal ?? 0) kcal")
print("Protein: \(nutritionData.proteinGrams ?? 0) g")
print("Carbs: \(nutritionData.carbohydratesGrams ?? 0) g")
print("Fat: \(nutritionData.fatGrams ?? 0) g")
```

### Metrics (Heart Rate & Body)

```swift
// Get heart rate metrics
let heartRateData = await healthService.getHeartRateMetrics(by: Date())

print("Average HR: \(heartRateData.averageHeartRate ?? 0) bpm")
print("Resting HR: \(heartRateData.restingHeartRate ?? 0) bpm")

// Get body metrics
let bodyData = await healthService.getBodyMetrics(by: Date())

print("Height: \(bodyData.height ?? 0) cm")
print("Weight: \(bodyData.weight ?? 0) kg")
```

### Workouts

```swift
// Get all workouts for today
let allWorkouts = try await healthService.getAllWorkouts(date: Date())

// Get specific workout type
let walkingWorkouts = try await healthService.getWorkoutsByType(
    ofType: .walking, 
    date: Date()
)

// Get raw HKWorkout objects
let hkWorkouts = try await healthService.getAllHKWorkouts(date: Date())
```

## Background Delivery

HealthKitManager supports background delivery to receive updates when health data changes, even when your app is not running.

### Enable Background Delivery

First, enable background delivery for the types you want to observe:

```swift
// Enable background delivery for walking activity
await healthService.enableBackgroundWalkingActivityUpdates(enabled: true)

// Enable for other activity types
await healthService.enableBackgroundSleepActivityUpdates(enabled: true)
await healthService.enableBackgroundMindfulActivityUpdates(enabled: true)
await healthService.enableBackgroundNutritionUpdates(enabled: true)
await healthService.enableBackgroundHeartRateUpdates(enabled: true)
await healthService.enableBackgroundWorkoutsUpdates(enabled: true)
```

### Observe Real-time Updates

Use observer methods to receive callbacks when data changes:

```swift
// Observe walking activity changes
healthService.observeWalkingActivityInBackground(true) { result in
    switch result {
    case .success(let walkingData):
        print("Updated steps: \(walkingData?.steps ?? 0)")
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Observe sleep activity changes
healthService.observeSleepActivityInBackground(true) { result in
    switch result {
    case .success(let sleepData):
        print("Updated sleep data received")
    case .failure(let error):
        print("Error: \(error)")
    }
}

// Observe mindful activity changes
healthService.observeMindfulActivityInBackground(true) { result in
    // Handle mindful data updates
}

// Observe nutrition changes
healthService.observeNutritionInBackground(true) { result in
    // Handle nutrition data updates
}

// Observe heart rate changes
healthService.observeHeartRateInBackground(true) { result in
    // Handle heart rate updates
}

// Observe workout changes
healthService.observeWorkoutsInBackground(true) { result in
    // Handle workout updates
}

// Stop observing (pass false)
healthService.observeWalkingActivityInBackground(false) { _ in }
```

### Background Delivery Setup in AppDelegate

For background delivery to work, register your observer in `application(_:didFinishLaunchingWithOptions:)`:

```swift
func application(_ application: UIApplication, 
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    let healthService = HealthService()
    
    // Enable background delivery
    Task {
        await healthService.enableBackgroundWalkingActivityUpdates(enabled: true)
    }
    
    // Start observing
    healthService.observeWalkingActivityInBackground(true) { result in
        // Handle updates
    }
    
    return true
}
```

## Available Protocols

| Protocol | Description |
|----------|-------------|
| `WalkingActivity` | Steps, distance, duration, calories, heart rate |
| `SleepActivity` | Sleep analysis (REM, deep, core, awake times) |
| `MindfulActivity` | Mindfulness session duration |
| `DietaryNutrition` | Calories, protein, carbs, fat, water intake |
| `Metrics` | Heart rate (average, resting) and body metrics |
| `WorkoutsActivity` | Workout sessions with detailed statistics |
| `HealthActivitiesPermission` | Authorization and background delivery |

## Data Models

### WalkingActivityData
- `date`: Date of the activity
- `steps`: Step count
- `activeCalories`: Active energy burned (kcal)
- `distanceMeters`: Distance in meters
- `durationMinutes`: Active minutes
- `averageHeartRate`: Average heart rate (bpm)

### SleepActivityData
- `awakeTimes`: Number of times awake
- `asleepREMInSeconds`: REM sleep duration
- `asleepCorepSeconds`: Core sleep duration
- `deepSleepSeconds`: Deep sleep duration

### MindfulActivityData
- `mindfulSeconds`: Total mindfulness duration

### DietaryNutritionData
- `caloriesKcal`: Energy consumed
- `carbohydratesGrams`: Carbohydrates
- `proteinGrams`: Protein
- `fatGrams`: Fat

### HeartRateData
- `restingHeartRate`: Resting heart rate
- `averageHeartRate`: Average heart rate

### BodyData
- `height`: Height in centimeters
- `weight`: Weight in kilograms

### WorkoutData
- Contains workout sessions with duration, calories, distance, heart rate, and source information

## License

MIT License

## Author

Fernando Fuentes
