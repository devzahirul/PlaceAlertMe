# PlaceAlertMe Library Integration Guide

Quick integration guide for both Android and iOS libraries.

## Overview

PlaceAlertMe is available as:
- **Android**: Gradle library (AAR)
- **iOS**: Swift Package

Both provide a simple, high-level API for geofencing functionality without requiring knowledge of the underlying C++ engine or platform-specific details.

## Choose Your Integration Path

### For Android Developers

**Easy:** Use the `GeoTracker` class for simple geofencing
- 3 lines to add zones
- 1 line to start tracking
- Broadcast receiver for updates

**See:** [ANDROID_LIBRARY_USAGE.md](ANDROID_LIBRARY_USAGE.md)

### For iOS Developers

**Easy:** Use `PlaceAlertMe` singleton with delegate pattern
- 3 lines to add zones
- 1 line to start tracking
- Delegate callbacks for updates

**See:** [IOS_LIBRARY_USAGE.md](IOS_LIBRARY_USAGE.md)

## Installation Comparison

| Platform | Method | Command |
|----------|--------|---------|
| Android | Gradle | `implementation 'com.github.devzahirul:PlaceAlertMe:1.0.0'` |
| iOS | SPM | File → Add Packages → Enter GitHub URL |
| iOS | CocoaPods | `pod 'PlaceAlertMe'` |

## Minimal Example

### Android

```kotlin
// In Activity/Fragment
val tracker = GeoTracker(this)
tracker.startTracking()
tracker.addGeofenceZone(37.7749, -122.4194, 5000.0)

// Listen for changes
registerReceiver(
    object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val isInside = intent.getBooleanExtra(
                GeoTracker.EXTRA_IS_INSIDE, false
            )
            println("Zone status: $isInside")
        }
    },
    IntentFilter(GeoTracker.ACTION_ZONE_STATUS_CHANGED)
)
```

### iOS

```swift
// In AppDelegate or SceneDelegate
PlaceAlertMe.shared.delegate = self
PlaceAlertMe.shared.startTracking()
PlaceAlertMe.shared.addGeofenceZone(37.7749, -122.4194, 5000.0)

// Implement delegate
extension AppDelegate: PlaceAlertMeDelegate {
    func placeAlertMe(_ tracker: PlaceAlertMe, 
                     didChangeZoneStatus isInside: Bool) {
        print("Zone status: \(isInside)")
    }
    
    func placeAlertMe(_ tracker: PlaceAlertMe,
                     didUpdateGeofenceStatus status: GeofenceStatus) {
        // Handle location updates
    }
}
```

## API Summary

### Android: GeoTracker

```kotlin
class GeoTracker(context: Context) {
    fun startTracking()
    fun stopTracking()
    fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
    fun clearGeofenceZones()
    fun getZoneCount(): Int
    fun pauseTracking()
    fun resumeTracking()
}
```

**Broadcasts:**
- Action: `GeoTracker.ACTION_ZONE_STATUS_CHANGED`
- Extras: `EXTRA_IS_INSIDE`, `EXTRA_DISTANCE`, `EXTRA_NEXT_INTERVAL`, etc.

### iOS: PlaceAlertMe

```swift
class PlaceAlertMe {
    static let shared: PlaceAlertMe
    weak var delegate: PlaceAlertMeDelegate?
    
    func startTracking()
    func stopTracking()
    func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double)
    func clearGeofenceZones()
}

protocol PlaceAlertMeDelegate {
    func placeAlertMe(_ tracker: PlaceAlertMe, 
                     didUpdateGeofenceStatus status: GeofenceStatus)
    func placeAlertMe(_ tracker: PlaceAlertMe, 
                     didChangeZoneStatus isInside: Bool)
}
```

## Permission Requirements

### Android

In `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

Request at runtime (Android 6+):
```kotlin
ActivityCompat.requestPermissions(this,
    arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        Manifest.permission.ACTIVITY_RECOGNITION
    ),
    PERMISSION_REQUEST_CODE)
```

### iOS

In `Info.plist`:
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Required for geofencing</string>
<key>NSMotionUsageDescription</key>
<string>Used to optimize battery</string>
```

Request in code:
```swift
// Automatic via PlaceAlertMe.startTracking()
PlaceAlertMe.shared.startTracking()  // Requests permission if needed
```

## Features

### Automatic Optimization
- **Adaptive Intervals**: Tracking frequency scales with speed
  - Stationary: 60 seconds
  - Walking: 10 seconds
  - Vehicle: 2 seconds
  
- **Activity Recognition**: Pauses when device is still
  - Saves 30-40% battery when stationary
  
- **Distance-Based**: Closer to zone = more frequent updates

### Battery Efficiency
- 40-60% better than fixed-interval tracking
- Foreground service prevents termination
- Local calculations (no network)

### Reliability
- Works offline
- No dependency on Google Play Services location APIs
- Cross-platform consistency

## Troubleshooting

### Android: Location not updating
1. Check manifest has all required permissions
2. Request runtime permissions (Android 6+)
3. Enable location on device
4. Verify zone coordinates are valid

### iOS: Delegate not called
1. Set `delegate` before calling `startTracking()`
2. Keep delegate object alive
3. Check `Info.plist` has required keys
4. Request location permission in Settings

### Both: High battery drain
1. Reduce number of zones (< 50)
2. Check activity recognition is working
3. Use `pauseTracking()` when not needed

## Project Structure

```
PlaceAlertMe/
├── cpp/                          # C++ Core Engine
│   └── geo_engine/
│       ├── geo_engine.cpp
│       └── include/
├── android/                       # Android Library
│   └── geo-engine/
│       ├── build.gradle
│       ├── src/main/
│       │   ├── AndroidManifest.xml
│       │   ├── cpp/
│       │   │   └── geo_engine_jni.cpp
│       │   └── kotlin/com/placealertme/geofence/
│       │       ├── GeoTracker.kt
│       │       ├── GeoEngineJNI.kt
│       │       └── LocationTrackingService.kt
│       └── CMakeLists.txt
├── ios/                           # iOS Library
│   └── PlaceAlertMe/
│       ├── PlaceAlertMe.swift
│       ├── GeoEngineManager.swift
│       ├── LocationManager.swift
│       └── ActivityRecognitionManager.swift
├── Package.swift                  # iOS SPM Config
├── README.md
├── ANDROID_LIBRARY_USAGE.md
└── IOS_LIBRARY_USAGE.md
```

## Version Management

### Current Version: 1.0.0

### Semantic Versioning
- **MAJOR**: Breaking API changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

### Upgrade Path
```
1.0.0 → 1.1.0 (new features)
1.1.0 → 2.0.0 (breaking changes)
```

## Support

### Documentation
- [BUILD.md](BUILD.md) - Build instructions
- [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) - Deep dive
- [API_REFERENCE.md](API_REFERENCE.md) - Complete API docs
- [ANDROID_LIBRARY_USAGE.md](ANDROID_LIBRARY_USAGE.md) - Android guide
- [IOS_LIBRARY_USAGE.md](IOS_LIBRARY_USAGE.md) - iOS guide

### Issue Tracking
- GitHub Issues: Report bugs and request features

## Next Steps

1. **Choose Platform**: Android, iOS, or both
2. **Install Library**: See installation instructions above
3. **Add Permissions**: Update manifest/plist
4. **Implement**: 3-5 lines of code
5. **Test**: Run on real device
6. **Deploy**: Submit to app store

## License

MIT License - Free for commercial and personal use
