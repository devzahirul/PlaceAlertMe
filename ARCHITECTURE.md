# PlaceAlertMe Architecture

## System Design

### 1. C++ Core Engine Layer
The C++ core engine is a platform-agnostic library that handles all geofencing calculations and adaptive interval logic.

**Key Responsibilities:**
- Haversine distance calculations
- Zone containment detection
- Adaptive interval calculation based on speed and distance
- State management

### 2. Android Layer
**Technology Stack:**
- Kotlin for Android app logic
- FusedLocationProviderClient for location updates
- Activity Recognition API for motion detection
- Foreground Service for persistent tracking
- JNI for C++ integration

**Tracking Flow:**
1. Foreground Service monitors device activity
2. If device is moving, request location updates from FusedLocationProviderClient
3. Pass location data to C++ core engine
4. Receive recommended next tracking interval
5. Schedule next update based on interval
6. Pause tracking when Activity Recognition detects STILL state

### 3. iOS Layer
**Technology Stack:**
- Swift for iOS app logic
- CoreLocation for background location updates
- CoreMotion for activity detection
- Swift C-Interop for C++ integration

**Tracking Flow:**
1. CoreLocation manager starts background tracking
2. Activity detection via CMMotionActivityManager
3. Pause tracking when activity indicates stationary state
4. Pass location data to C++ core engine
5. Update CoreLocation accuracy based on engine recommendations
6. Schedule next location request

## Data Flow Diagram

```
┌─────────────────────────────────────────────────┐
│         Platform-Specific Location Source       │
│    (FusedLocationProviderClient / CoreLocation) │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│         Platform-Specific Bridge Layer          │
│    (JNI / Swift C-Interop / Objective-C++)     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│          C++ Core Engine (geo_engine)           │
│  - Haversine Calculation                        │
│  - Zone Detection                               │
│  - Adaptive Interval Logic                      │
│  - State Management                             │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│      Response to Platform Layer                 │
│  (isInsideZone, nextIntervalMs)                │
└─────────────────────────────────────────────────┘
```

## Adaptive Interval Algorithm

```
if speed < 1.0 m/s (stationary):
    nextInterval = 60000 ms (60 seconds)
else if speed < 5.0 m/s (walking):
    nextInterval = 10000 ms (10 seconds)
else if speed < 15.0 m/s (running/cycling):
    nextInterval = 5000 ms (5 seconds)
else:
    nextInterval = 2000 ms (2 seconds)

if distance_to_zone > radius * 2:
    nextInterval *= 2 (double interval when far from zone)
else if distance_to_zone < radius * 0.5:
    nextInterval = min(nextInterval, 5000 ms) (increase frequency near zone)
```

## Battery Optimization Strategies

1. **Adaptive Frequency:** Tracking interval scales with speed and distance
2. **Activity Recognition:** Pause tracking when device is stationary
3. **Accuracy Adjustment:** Request lower accuracy when far from zones
4. **Batched Updates:** Group location updates when possible
5. **Background Optimization:** Use foreground services efficiently on Android
