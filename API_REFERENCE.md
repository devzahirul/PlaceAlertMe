# PlaceAlertMe API Reference

Complete API documentation for the C++ Core Engine and platform-specific integrations.

## C++ Core Engine API

### Header File
```cpp
#include "geo_engine.h"

namespace geo_engine {
    // Main classes and structures
}
```

### Data Structures

#### UserLocation
Represents the current user location with speed information.

```cpp
struct UserLocation {
    double latitude;      // Latitude in degrees (-90 to 90)
    double longitude;     // Longitude in degrees (-180 to 180)
    double speedMps;      // Speed in meters per second (>= 0)
    
    UserLocation();  // Default constructor, initializes to 0,0,0
    UserLocation(double lat, double lon, double speed);  // Full constructor
};
```

#### GeofenceZone
Represents a circular geofence zone.

```cpp
struct GeofenceZone {
    double latitude;      // Zone center latitude
    double longitude;     // Zone center longitude
    double radiusMeters;  // Zone radius in meters (> 0)
    
    GeofenceZone();  // Default constructor
    GeofenceZone(double lat, double lon, double radius);  // Full constructor
};
```

#### EngineResponse
Response from the engine after processing a location.

```cpp
struct EngineResponse {
    bool isInsideZone;           // True if location is inside any zone
    int64_t nextIntervalMs;      // Recommended next update interval in ms
    double distanceMeters;       // Distance to nearest zone center
    
    EngineResponse();  // Default: false, 60000ms, 0.0m
};
```

### GeoEngine Class

#### Constructor/Destructor
```cpp
GeoEngine();   // Initialize empty engine
~GeoEngine();  // Cleanup
```

#### Zone Management

**add Zone**
```cpp
void addZone(const GeofenceZone& zone);
```
- Adds a new geofence zone to the engine
- Zones are cumulative (adding doesn't clear previous zones)
- No duplicate detection

**removeZone**
```cpp
void removeZone(size_t index);
```
- Removes zone at specified index
- Index must be < getZoneCount()
- Safe to call with invalid index (no-op)

**clearZones**
```cpp
void clearZones();
```
- Removes all geofence zones
- Calling processLocation() with no zones returns default response

**getZoneCount**
```cpp
size_t getZoneCount() const;
```
- Returns current number of zones
- Return value: >= 0

**initialize**
```cpp
void initialize(const std::vector<GeofenceZone>& zones);
```
- Initialize engine with a set of zones
- Clears previous zones
- Takes vector of GeofenceZone

#### Location Processing

**processLocation**
```cpp
EngineResponse processLocation(const UserLocation& location);
```
- Main processing function
- Input: Current user location with speed
- Output: Zone status and tracking recommendations
- Handles:
  - Zone containment detection
  - Haversine distance calculation
  - Adaptive interval calculation
  - State tracking (last location)

**Example:**
```cpp
GeoEngine engine;
engine.addZone({37.7749, -122.4194, 1000.0});  // San Francisco, 1km radius

UserLocation current(37.7749, -122.4194, 2.5);  // At zone center, walking
EngineResponse response = engine.processLocation(current);

// response.isInsideZone = true
// response.nextIntervalMs = 10000 (walking speed)
// response.distanceMeters = 0.0
```

### Private Methods (Internal)

#### calculateDistance
```cpp
double calculateDistance(double lat1, double lon1, double lat2, double lon2) const;
```
- Haversine formula implementation
- Input: Two coordinate pairs (latitude, longitude)
- Output: Distance in meters
- Constants:
  - Earth radius: 6,371,000 meters
  - Degrees to radians: π/180

#### calculateAdaptiveInterval
```cpp
int64_t calculateAdaptiveInterval(double speedMps, double distanceToNearestZone, 
                                  double radiusOfNearestZone) const;
```
- Determines next tracking interval
- Algorithm:
  1. Select base interval by speed
  2. Adjust by distance to nearest zone
  3. Clamp to min/max bounds
- Returns interval in milliseconds

**Speed-Based Intervals:**
| Speed Range | Interval |
|-------------|----------|
| < 1.0 m/s | 60,000 ms |
| 1.0-5.0 m/s | 10,000 ms |
| 5.0-15.0 m/s | 5,000 ms |
| > 15.0 m/s | 2,000 ms |

**Distance-Based Adjustments:**
| Distance | Adjustment |
|----------|------------|
| > radius×2 | ×2 interval |
| < radius×0.5 | Clamp to 5,000ms |

**Final Bounds:**
- Minimum: 1,000 ms (1 second)
- Maximum: 120,000 ms (2 minutes)

#### checkZoneContainment
```cpp
std::pair<bool, double> checkZoneContainment(const UserLocation& location) const;
```
- Checks location against all zones
- Returns: (isInsideAny, distanceToNearest)
- O(n) complexity where n = number of zones

## Android API

### GeoEngineJNI (Kotlin)

Singleton object providing JNI access to C++ engine.

```kotlin
object GeoEngineJNI {
    // External native functions
    external fun initializeEngine()
    external fun addZone(latitude: Double, longitude: Double, radiusMeters: Double)
    external fun processLocation(latitude: Double, longitude: Double, speedMps: Double): LongArray
    external fun clearZones()
    external fun getZoneCount(): Int
    
    // Convenience wrapper
    fun processLocationWrapped(latitude: Double, longitude: Double, speedMps: Double): EngineResponse
    
    // Data class
    data class EngineResponse(
        val isInsideZone: Boolean,
        val nextIntervalMs: Long,
        val distanceMeters: Double
    )
}
```

#### Methods

**initializeEngine()**
- Initializes C++ engine
- Must be called before first use
- Safe to call multiple times (idempotent)

**addZone**
```kotlin
fun addZone(latitude: Double, longitude: Double, radiusMeters: Double)
```
- Adds geofence zone
- Parameters:
  - latitude: -90 to 90
  - longitude: -180 to 180
  - radiusMeters: > 0

**processLocation**
```kotlin
fun processLocation(latitude: Double, longitude: Double, speedMps: Double): LongArray
```
- Processes location update (low-level)
- Returns: LongArray with 3 elements
  - [0]: isInsideZone (0/1)
  - [1]: nextIntervalMs
  - [2]: distanceMeters (as long)

**processLocationWrapped**
```kotlin
fun processLocationWrapped(latitude: Double, longitude: Double, speedMps: Double): EngineResponse
```
- Processes location update (high-level)
- Returns: EngineResponse data class
- Recommended over processLocation

**clearZones()**
- Removes all zones
- Engine remains active

**getZoneCount(): Int**
- Returns number of active zones

### LocationTrackingService

Android foreground service for persistent location tracking.

```kotlin
class LocationTrackingService : Service
```

#### Key Methods

**addGeofenceZone**
```kotlin
fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
```

**clearGeofenceZones()**
- Removes all zones

**pauseTracking()**
- Pauses location updates
- Service remains active

**resumeTracking()**
- Resumes location updates

#### Broadcasts

**ACTION_ZONE_STATUS_CHANGED**
- Intent action: `"com.placealertme.ZONE_STATUS_CHANGED"`
- Broadcast whenever zone status changes
- Extras:
  - `"isInside"` (Boolean): Inside any zone
  - `"distance"` (Double): Distance to nearest zone
  - `"nextInterval"` (Long): Next update interval in ms

### ActivityRecognitionHelper

Activity detection using Google Play Services.

```kotlin
class ActivityRecognitionHelper(context: Context)
```

#### Methods

**startActivityRecognition()**
- Starts activity updates (10-second interval)
- Detected activities:
  - STILL: Device stationary
  - WALKING: Walking motion
  - RUNNING: Running motion
  - CYCLING: Cycling motion
  - IN_VEHICLE: Vehicle motion

**stopActivityRecognition()**
- Stops activity updates

### GeoTrackingManager

Singleton coordinator for the entire tracking system.

```kotlin
class GeoTrackingManager(context: Context) {
    companion object {
        fun getInstance(context: Context): GeoTrackingManager
    }
}
```

#### Methods

**startTracking()**
- Starts location and activity tracking
- Starts foreground service
- Begins activity recognition
- Safe to call multiple times

**stopTracking()**
- Stops all tracking
- Stops foreground service
- Stops activity recognition

**addGeofenceZone**
```kotlin
fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
```

**clearGeofenceZones()**

**pauseTracking()**
- Pauses location updates only
- Service and activity recognition continue

**resumeTracking()**
- Resumes location updates

## iOS API

### GeoEngineManager

Swift wrapper around C++ geofencing engine.

```swift
class GeoEngineManager {
    static let shared: GeoEngineManager
    
    func addZone(latitude: Double, longitude: Double, radiusMeters: Double)
    func clearZones()
    func getZoneCount() -> Int
    func processLocation(latitude: Double, longitude: Double, speedMps: Double) -> GeoEngineResponse
}

struct GeoEngineResponse {
    let isInsideZone: Bool
    let nextIntervalMs: Int64
    let distanceMeters: Double
    var nextIntervalSeconds: TimeInterval { get }
}
```

#### Methods

**shared**
- Singleton instance
- Lazily initialized
- Thread-safe

**addZone**
```swift
func addZone(latitude: Double, longitude: Double, radiusMeters: Double)
```

**clearZones()**

**getZoneCount() -> Int**

**processLocation**
```swift
func processLocation(latitude: Double, longitude: Double, speedMps: Double) -> GeoEngineResponse
```
- Main processing function
- Returns response with zone status and next interval

### LocationManager

CoreLocation integration with adaptive accuracy.

```swift
protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdate location: CLLocation, response: GeoEngineResponse)
    func locationManager(_ manager: LocationManager, didChangeZoneStatus isInside: Bool)
}

class LocationManager: NSObject, CLLocationManagerDelegate {
    weak var delegate: LocationManagerDelegate?
    
    func requestLocationPermission()
    func startTracking()
    func stopTracking()
    func pauseTracking()
    func resumeTracking()
    func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
    func clearGeofenceZones()
}
```

#### Methods

**requestLocationPermission()**
- Requests iOS location permission
- Uses always+when-in-use on iOS 14+
- Uses always on iOS 13

**startTracking()**
- Requests permissions
- Enables background location updates
- Starts location updates

**stopTracking()**
- Stops location updates
- Stops update timer

**pauseTracking()**
- Temporary pause
- Service remains ready

**resumeTracking()**
- Resumes after pause

**addGeofenceZone**
```swift
func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
```

**clearGeofenceZones()**

#### Delegate Methods

**locationManager(_:didUpdate:response:)**
```swift
func locationManager(_ manager: LocationManager, 
                    didUpdate location: CLLocation, 
                    response: GeoEngineResponse)
```
- Called on each location update
- Runs on main thread
- Provides location and engine response

**locationManager(_:didChangeZoneStatus:)**
```swift
func locationManager(_ manager: LocationManager, 
                    didChangeZoneStatus isInside: Bool)
```
- Called when zone status changes
- Only called on transitions (not repeated)

### ActivityRecognitionManager

CoreMotion activity detection.

```swift
protocol ActivityRecognitionDelegate: AnyObject {
    func activityRecognitionManager(_ manager: ActivityRecognitionManager, 
                                  didDetectActivity activity: CMMotionActivity)
}

class ActivityRecognitionManager {
    weak var delegate: ActivityRecognitionDelegate?
    
    func startActivityRecognition()
    func stopActivityRecognition()
    static func isActivityStill(_ activity: CMMotionActivity) -> Bool
    static func isActivityMoving(_ activity: CMMotionActivity) -> Bool
}
```

#### Methods

**startActivityRecognition()**
- Starts continuous activity monitoring
- Requires motion permission
- Gracefully fails if unavailable

**stopActivityRecognition()**
- Stops activity monitoring

**isActivityStill**
```swift
static func isActivityStill(_ activity: CMMotionActivity) -> Bool
```
- Returns true if activity.stationary

**isActivityMoving**
```swift
static func isActivityMoving(_ activity: CMMotionActivity) -> Bool
```
- Returns true if walking, running, cycling, or automotive

### TrackingCoordinator

Main coordinator for iOS tracking system.

```swift
class TrackingCoordinator: NSObject {
    static let shared: TrackingCoordinator
    
    func startTracking()
    func stopTracking()
    func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
    func clearGeofenceZones()
}
```

#### Methods

**shared**
- Singleton instance

**startTracking()**
- Starts location and activity tracking
- Safe to call multiple times

**stopTracking()**
- Stops all tracking

**addGeofenceZone**

**clearGeofenceZones()**

#### Notifications

**GeofenceStatusChanged**
- Name: `NSNotification.Name("GeofenceStatusChanged")`
- UserInfo:
  - `"isInside"` (Bool)
  - `"latitude"` (Double)
  - `"longitude"` (Double)
  - `"distance"` (Double)
  - `"nextInterval"` (Int64)

**GeofenceZoneStatusChanged**
- Name: `NSNotification.Name("GeofenceZoneStatusChanged")`
- UserInfo:
  - `"isInside"` (Bool)

## Error Handling

### Android

```kotlin
try {
    trackingManager.startTracking()
} catch (e: SecurityException) {
    // Missing location permission
}
```

### iOS

```swift
// Check location authorization before starting
let status = CLLocationManager.authorizationStatus()
if status == .authorizedAlways || status == .authorizedWhenInUse {
    coordinator.startTracking()
}
```

## Threading Model

### C++ Core
- Thread-safe for read-only operations
- Not thread-safe for zone modifications
- processLocation() can be called from any thread

### Android
- GeoEngineJNI: Safe from any thread
- LocationTrackingService: Callbacks on main thread
- Activity callbacks: Run on dedicated thread (safe)

### iOS
- LocationManager delegate: Main thread
- Activity manager: Background thread (updates on main thread)
- Notifications: Posted on notification thread

## Memory and Performance

### Memory Usage
- C++ Core: ~100-200 KB base
- Per Zone: ~200 bytes
- Per Platform Layer: ~500 KB (service/manager objects)

### Latency
- Haversine distance: < 0.5 ms
- Interval calculation: < 0.1 ms
- Zone containment check: < 1 ms (for < 50 zones)
- Total processLocation(): < 1.5 ms

### Battery
- At 10-second interval: 5-7% per hour
- Scales with interval and movement
- Activity recognition reduces battery by 30-40%
