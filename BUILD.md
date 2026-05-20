# PlaceAlertMe Build Guide

## Prerequisites

### Common
- C++17 compiler
- CMake 3.18+

### Android
- Android NDK (r25.1.8937393 or compatible)
- Android SDK (API 34)
- Gradle 8.0+
- Java 11+

### iOS
- Xcode 14+
- Swift 5.7+
- iOS Deployment Target: 13.0+
- CocoaPods

## Building the C++ Core Engine

### Core Library
The C++ core is built automatically by both Android and iOS builds, but can also be built standalone:

```bash
mkdir build
cd build
cmake ..
make
```

## Android Build

### 1. Build C++ Library with NDK
The CMake configuration automatically builds the C++ core via JNI:

```bash
cd android
./gradlew build
```

### 2. Specific Build Variants

Release build:
```bash
./gradlew assembleRelease
```

Debug build:
```bash
./gradlew assembleDebug
```

### 3. Build Output
- C++ compiled to `.so` files in: `android/app/build/intermediates/cmake/`
- JNI bindings compiled automatically
- APK location: `android/app/build/outputs/apk/`

## iOS Build

### 1. Using CocoaPods

```bash
cd ios
pod install
```

### 2. Build Framework with CMake

```bash
cd ios
mkdir build
cd build
cmake -GXcode -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" ..
cmake --build . --config Release
```

### 3. Manual Xcode Build

```bash
cd ios
open PlaceAlertMe.xcworkspace
# Build in Xcode (Cmd+B)
```

### 4. Build Output
- C++ framework: `ios/build/Release-iphoneos/geo_engine_ios.a`
- Swift binaries compiled automatically

## Integration Steps

### Android Integration

1. **Add GeoEngineJNI to your Activity:**
```kotlin
GeoEngineJNI.initializeEngine()
```

2. **Start location tracking:**
```kotlin
val trackingManager = GeoTrackingManager.getInstance(context)
trackingManager.startTracking()
```

3. **Add geofence zones:**
```kotlin
trackingManager.addGeofenceZone(
    latitude = 37.7749,
    longitude = -122.4194,
    radiusMeters = 1000.0
)
```

### iOS Integration

1. **Add TrackingCoordinator to your app:**
```swift
TrackingCoordinator.shared.startTracking()
```

2. **Add geofence zones:**
```swift
TrackingCoordinator.shared.addGeofenceZone(
    latitude: 37.7749,
    longitude: -122.4194,
    radiusMeters: 1000.0
)
```

3. **Listen for zone changes:**
```swift
NotificationCenter.default.addObserver(
    forName: NSNotification.Name("GeofenceStatusChanged"),
    object: nil,
    queue: .main
) { notification in
    if let isInside = notification.userInfo?["isInside"] as? Bool {
        print("Zone status: \(isInside ? "INSIDE" : "OUTSIDE")")
    }
}
```

## Troubleshooting

### Android

**CMake compilation errors:**
- Ensure NDK version matches build.gradle (25.1.8937393)
- Clear build cache: `./gradlew clean`

**JNI crashes:**
- Check native method signatures match JNI expectations
- Verify `System.loadLibrary("geo_engine_jni")` succeeds

**Permission denied errors:**
- Verify AndroidManifest.xml contains all required permissions
- Request runtime permissions on Android 6+

### iOS

**C++ interop errors:**
- Ensure Objective-C++ file extension is `.mm`
- Check include paths in build settings

**CMake issues:**
- Verify CMakeLists.txt architecture matches target device
- Clean build folder: `rm -rf build/`

**Symbol not found:**
- Ensure C++ framework is linked in Link Binary With Libraries
- Check deployment target compatibility

## Performance Optimization

### Android
- Foreground Service prevents process termination
- Activity Recognition API pauses tracking when stationary
- FusedLocationProviderClient batches updates efficiently
- ARM NEON optimization enabled for supported devices

### iOS
- Background location updates configured
- Adaptive accuracy adjusts based on distance to geofence
- CoreMotion activity detection reduces battery drain
- Timer-based update scheduling prevents excessive location queries

## Testing

### Android
```bash
# Run unit tests
./gradlew testDebugUnitTest

# Run instrumented tests
./gradlew connectedAndroidTest
```

### iOS
```bash
# Run tests in Xcode
cmd+U

# Or via command line
xcodebuild test -scheme PlaceAlertMe
```
