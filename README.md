# PlaceAlertMe - Custom Geofencing Library

A highly optimized, battery-efficient cross-platform geofencing library for Android (Kotlin) and iOS (Swift) using a shared C++ Core Engine.

## Quick Integration

### Android
```gradle
dependencies {
    implementation 'com.github.devzahirul:PlaceAlertMe:1.0.0'
}
```

```kotlin
val tracker = GeoTracker(this)
tracker.startTracking()
tracker.addGeofenceZone(37.7749, -122.4194, 5000.0)
```

**→ [Android Usage Guide](ANDROID_LIBRARY_USAGE.md)**

### iOS
```swift
import PlaceAlertMe

PlaceAlertMe.shared.delegate = self
PlaceAlertMe.shared.startTracking()
PlaceAlertMe.shared.addGeofenceZone(37.7749, -122.4194, 5000.0)
```

**→ [iOS Usage Guide](IOS_LIBRARY_USAGE.md)**

## Architecture Overview

### Core Components
1. **C++ Core Engine** (`cpp/geo_engine/`) - Pure C++17 geofencing calculations
2. **Android Library** (`android/geo-engine/`) - Gradle AAR for easy integration
3. **iOS Library** (`ios/PlaceAlertMe/`) - Swift Package for easy integration

### Key Features
✨ **Battery Efficient** - 40-60% better vs fixed intervals
✨ **Activity-Aware** - Pauses when device is still (30-40% savings)
✨ **No Native APIs** - Custom engine avoids Google Geofencing/iOS Region Monitoring
✨ **Cross-Platform** - Shared C++ core with native platform integrations
✨ **Easy Integration** - 3 lines of code to start

## Project Structure

```
PlaceAlertMe/
├── cpp/
│   └── geo_engine/              # C++ Core Engine (shared)
│       ├── geo_engine.cpp
│       └── include/geo_engine.h
├── android/
│   └── geo-engine/              # Android Library (AAR)
│       ├── build.gradle
│       ├── src/main/
│       │   ├── cpp/             # JNI bindings
│       │   └── kotlin/          # Public API
│       └── CMakeLists.txt
├── ios/
│   └── PlaceAlertMe/            # iOS Library (SPM)
│       ├── PlaceAlertMe.swift   # Public API
│       ├── GeoEngineManager.swift
│       └── ...
├── Package.swift                # iOS Swift Package config
└── README.md
```

## Documentation

### For Library Users
- **[LIBRARY_INTEGRATION.md](LIBRARY_INTEGRATION.md)** - Integration overview for both platforms
- **[ANDROID_LIBRARY_USAGE.md](ANDROID_LIBRARY_USAGE.md)** - Complete Android guide with examples
- **[IOS_LIBRARY_USAGE.md](IOS_LIBRARY_USAGE.md)** - Complete iOS guide with examples

### For Developers
- **[BUILD.md](BUILD.md)** - Build instructions for both platforms
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and data flow
- **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** - Detailed implementation details
- **[API_REFERENCE.md](API_REFERENCE.md)** - Complete API documentation

## Performance

| Scenario | Battery Impact |
|----------|----------------|
| Idle | 2-3% per hour |
| Walking | 5-7% per hour |
| Vehicle | 8-10% per hour |
| With Activity Detection | -30-40% vs normal |

## Requirements

### Android
- API 24+
- Kotlin 1.5+
- Google Play Services

### iOS
- iOS 13+
- Swift 5.5+
- Xcode 14+

## Getting Started

### Android
1. Add dependency to `build.gradle`
2. Add permissions to `AndroidManifest.xml`
3. Request runtime permissions (Android 6+)
4. Create `GeoTracker` and start tracking

**[→ Full Android Guide](ANDROID_LIBRARY_USAGE.md)**

### iOS
1. Add package via SPM or CocoaPods
2. Add permissions to `Info.plist`
3. Set delegate and start tracking
4. Implement delegate methods

**[→ Full iOS Guide](IOS_LIBRARY_USAGE.md)**

## Features

### Adaptive Tracking
- Speed-based interval adjustment
  - Stationary: 60 seconds
  - Walking: 10 seconds
  - Running: 5 seconds
  - Vehicle: 2 seconds
- Distance-based adjustments
  - Far from zone: 2× interval
  - Near zone: Minimum 5 seconds

### Activity Recognition
- Android: Google Play Services Activity Recognition API
- iOS: CoreMotion CMMotionActivityManager
- Automatic pause when still
- Resume on movement detection

### Accuracy Management
- iOS: Dynamic accuracy adjustment
  - Best accuracy: < 500m from zone
  - Degraded accuracy: > 5km from zone
- Android: FusedLocationProviderClient batching
- Local calculations (no network required)

## License

MIT License - Free for commercial and personal use

## Support

- GitHub Issues for bugs and features
- See documentation for troubleshooting
- Check examples in sample implementations
