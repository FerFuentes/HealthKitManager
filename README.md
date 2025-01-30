# HealthKit Workout

## Table of Contents
1. [Introduction to HealthKit Workouts](#introduction-to-healthkit-workouts)
2. [Workout Data Comparison Table](#workout-data-comparison-table)
3. [Explanation of Data Points](#explanation-of-data-points)
4. [Workout Data Examples](#workout-data-examples)

## Introduction to HealthKit Workouts

HealthKit is a framework provided by Apple that allows apps to gather and manage health-related data from various sources such as the iPhone, Apple Watch, and other health-tracking devices. One of the key features of HealthKit is its ability to track workouts, which can range from simple activities like walking to more complex activities like yoga and swimming. These workouts can be used for health monitoring, fitness tracking, and even medical research.

HealthKit categorizes workouts into different types, each with its own set of statistics. These workouts track a variety of data points including energy burned, heart rate, distance traveled, and more. By integrating these statistics into apps, users can track their fitness progress, set goals, and make data-driven decisions to improve their health.

### HealthKit Workout Types:
- **Walking**: Regular walking activities.
- **Running**: Running exercises, often with additional metrics like speed and power.
- **Cycling**: Data related to cycling activities.
- **Yoga**: Data from yoga workouts.
- **Swimming**: Statistics related to swimming workouts.
- **Rowing**: Data for rowing activities.
- **Functional Strength Training**: Strength exercises that require functional movements.
- **Climbing**: Includes activities like rock climbing.
- **Dance**: Dance-based workouts and activities.
- **Hiking**: Hiking and trail walking exercises.

Each of these activities has a unique set of statistics, which can be tracked using HealthKit.

## Workout Data Comparison Table

This table provides a comparison of the available statistics for each workout type in HealthKit. You can use this to understand what data is collected and tracked for each workout category.

| **Workout Type**               | **Active Energy Burned** | **Heart Rate**        | **Basal Energy Burned** | **Distance**        | **Steps**         | **Running Speed**   | **Running Power**   | **Swimming Stroke Count** |
|---------------------------------|--------------------------|-----------------------|-------------------------|---------------------|-------------------|---------------------|---------------------|---------------------------|
| **Walking**                     | ✓                        | ✓                     | ✓                       | ✓                   |                   |                     |                     |                           |
| **Running**                     | ✓                        | ✓                     | ✓                       | ✓                   | ✓                 | ✓                   | ✓                   |                           |
| **Cycling**                     | ✓                        | ✓                     | ✓                       |                     |                   |                     |                     |                           |
| **Yoga**                        | ✓                        | ✓                     | ✓                       |                     |                   |                     |                     |                           |
| **Swimming**                    | ✓                        | ✓                     | ✓                       | ✓                   |                   |                     |                     | ✓                         |
| **Rowing**                      | ✓                        | ✓                     | ✓                       |                     |                   |                     |                     |                           |
| **Functional Strength Training**| ✓                        | ✓                     | ✓                       |                     |                   |                     |                     |                           |
| **Climbing**                    | ✓                        | ✓                     | ✓                       |                     |                   |                     |                     |                           |
| **Dance**                       | ✓                        | ✓                     | ✓                       | ✓                   |                   |                     |                     |                           |
| **Hiking**                      | ✓                        | ✓                     | ✓                       | ✓                   |                   |                     |                     |                           |

---

## Workout Data Examples

### 1. **Walking Workout**

| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |

**Example JSON for Walking Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Walking",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 30.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "GMT+1",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "distanceMeters": 4000.0,
    "activeCalories": 150.0,
    "totalCalories": 180.0,
    "averageHeartRate": 110.0,
    "averageSpeed": 5.0,
    "steps": 5000.0
  }
}
```

### 2. **Running Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Step Count                 | HKStatistics                   |
| Running Speed              | HKStatistics                   |
| Running Power              | HKStatistics                   |
| Active Energy Burned       | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Distance Walking/Running   | HKStatistics                   |


**Example JSON for Running Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Running",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 30.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "stepCount": 6000.0,
    "runningSpeed": 12.0,
    "runningPower": 250.0,
    "activeCalories": 350.0,
    "totalCalories": 400.0,
    "averageHeartRate": 145.0,
    "distanceWalkingRunning": 6000.0
  }
}
```

### 3. **Cycling Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |


**Example JSON for Cycling Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Cycling",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 30.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "activeCalories": 300.0,
    "totalCalories": 350.0,
    "restingHeartRate": 70.0,
    "averageCadence": 85.0,
    "averagePower": 180.0,
    "averageSpeed": 20.0
  }
}
```

### 4. **Yoga Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |


**Example JSON for Yoga Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Yoga",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 60.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "activeCalories": 200.0,
    "totalCalories": 220.0,
    "averageHeartRate": 110.0
  }
}
```

### 5. **Swimming Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Distance Swimming          | HKStatistics                   |
| Swimming Stroke Count      | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |


**Example JSON for Swimming Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Swimming",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 45.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "distanceSwimming": 1200.0,
    "swimmingStrokeCount": 1500.0,
    "activeCalories": 350.0,
    "totalCalories": 400.0
  }
}
```

### 6. **Rowing Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |


**Example JSON for Rowing Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Rowing",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 30.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "activeCalories": 220.0,
    "totalCalories": 250.0,
    "averageHeartRate": 125.0
  }
}
```

### 7. **Functional Strength Training Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |


**Example JSON for Functional Strength Training Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Functional Strength Training",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 45.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "activeCalories": 400.0,
    "totalCalories": 450.0,
    "averageHeartRate": 135.0
  }
}
```

### 8. **Climbing Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Active Energy Burned       | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |


**Example JSON for Climbing Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Climbing",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 30.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "activeCalories": 350.0,
    "totalCalories": 400.0,
    "averageHeartRate": 140.0
  }
}
```

### 9. **Dance Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Distance Walking/Running   | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Active Energy Burned       | HKStatistics                   |


**Example JSON for Dance Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Dance",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 30.0,
  "restingHeartRate": 70.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "distanceWalkingRunning": 3000.0,
    "activeCalories": 250.0,
    "totalCalories": 280.0,
    "averageHeartRate": 120.0
  }
}
```

### 10. **Hiking Workout**
| Metric                    | Value                          |
|---------------------------|--------------------------------|
| Distance Walking/Running   | HKStatistics                   |
| Basal Energy Burned        | HKStatistics                   |
| Heart Rate                 | HKStatistics                   |
| Active Energy Burned       | HKStatistics                   |


**Example JSON for Hiking Workout:**

```json
{
  "id": "C390B8D2-A2F3-4C20-9A6C-86F8D37AA435",
  "type": "Hiking",
  "startTime": "2025-01-29 4:46:53 PM +0000",
  "endTime": "2025-01-29 4:46:53 PM +0000",
  "durationMinutes": 45.0,
  "restingHeartRate": 70.0,
  "averageMETs": 4.0,
  "indoorWorkout": false,
  "timeZone": "America/Tijuana",
  "humidityPorcentage": 55.0,
  "wetherTemperatureOnFahrenheit": 68.0,
  "metadata": {
    "distanceWalkingRunning": 7000.0,
    "activeCalories": 350.0,
    "totalCalories": 400.0,
    "averageHeartRate": 130.0,
  }
}
```

---

> **Note:** The value of `HKStatistics` depends on the specific `HKUnit` used for each metric. For example, `Active Energy Burned` could be represented in kilocalories (`kcal`), while `Heart Rate` might be measured in beats per minute (`bpm`). Each statistic's unit is important for proper interpretation of the data.
---

## Explanation of Data Points

Here’s an explanation of the key data points collected for each workout:

- **Active Energy Burned**: The total amount of energy (measured in kilocalories) burned during the workout, accounting for both exercise and rest periods.
- **Heart Rate**: The average heart rate (beats per minute) during the workout, giving insight into the intensity of the exercise.
- **Basal Energy Burned**: The amount of energy used by your body for basic functions such as breathing, circulation, and digestion while you are active.
- **Distance**: The total distance covered during the workout, measured in units like meters, kilometers, or miles (e.g., for walking, running, and swimming).
- **Steps**: The total number of steps taken during the workout, applicable for walking and running exercises.
- **Running Speed**: The speed at which you are running, typically measured in meters per second or miles per hour.
- **Running Power**: A measure of the effort (or power) exerted during running, typically in watts.
- **Swimming Stroke Count**: The number of swimming strokes made during the workout, typically used to track swimming performance.

---

## Additional Metadata for Workouts

In addition to the basic statistics, HealthKit also provides additional metadata for each workout that offers more context about the workout environment. This metadata includes:

| **Metadata**                 | **Description**                               |
|------------------------------|-----------------------------------------------|
| **Average METs**              | The average Metabolic Equivalent of Task (METs) for the workout. METs represent the intensity of the activity, with higher values indicating more intense exercises. |
| **Indoor Workout**            | A boolean value indicating whether the workout took place indoors (true) or outdoors (false). |
| **Time Zone**                 | The time zone in which the workout took place. |
| **Humidity**                  | The humidity level during the workout (if available). |
| **Temperature**               | The temperature during the workout (if available). |

> **Note:** 
> - The **Average METs** value is measured using the unit `kcal/(kg*hr)`.
> - The **Humidity** value is measured in percent (`%`).
> - The **Temperature** value is measured in degrees Fahrenheit (`°F`).
