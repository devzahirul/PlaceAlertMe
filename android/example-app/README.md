# PlaceAlertMe Example App

A complete example Android app demonstrating the PlaceAlertMe geofencing library with Jetpack Compose UI and OpenStreetMap integration.

## Features

✨ **Jetpack Compose UI**
- Modern Material Design 3 interface
- Compose Navigation for multi-screen app
- Responsive layouts

✨ **OpenStreetMap Integration**
- Interactive map for location selection
- Real-time geofence zone visualization
- Touch-based location picking

✨ **Geofencing Management**
- Create circular geofence zones
- Adjust radius dynamically
- View active zones
- Start/stop location tracking

✨ **Adaptive Tracking**
- Battery-efficient location updates
- Activity recognition (pause when still)
- Speed-based interval adjustment

## Screens

### Home Screen
- Tracking status toggle
- Zone statistics
- Quick action buttons
- List of active zones
- Add zone dialog

### Map Screen
- OpenStreetMap display
- Location selection by tapping
- Radius adjustment with slider
- Visual zone representation
- Zoom controls

### Settings Screen
- Notifications toggle
- Battery optimization settings
- Background tracking toggle
- App version info
- About section

## Project Structure

```
example-app/
├── build.gradle
├── proguard-rules.pro
├── src/main/
│   ├── AndroidManifest.xml
│   ├── kotlin/com/placealertme/example/
│   │   ├── MainActivity.kt
│   │   └── ui/
│   │       ├── screens/
│   │       │   ├── HomeScreen.kt
│   │       │   ├── MapScreen.kt
│   │       │   └── SettingsScreen.kt
│   │       └── theme/
│   │           ├── Theme.kt
│   │           └── Type.kt
│   └── res/
│       └── values/
│           ├── strings.xml
│           └── themes.xml
└── README.md
```

## Dependencies

### PlaceAlertMe Library
```gradle
implementation project(':geo-engine')
```

### Jetpack Compose
- `androidx.compose.ui:ui:1.5.3`
- `androidx.compose.material3:material3:1.1.1`
- `androidx.activity:activity-compose:1.8.0`
- `androidx.navigation:navigation-compose:2.7.4`

### Maps
- `org.osmdroid:osmdroid-android:6.1.14`

### Location
- `com.google.android.gms:play-services-location:21.0.1`

### Permissions
- `com.google.accompanist:accompanist-permissions:0.32.0`

## Building

### Debug Build
```bash
cd android
./gradlew assembleDebug
```

**Output:** `example-app/build/outputs/apk/debug/example-app-debug.apk`

### Release Build
```bash
cd android
./gradlew assembleRelease
```

**Output:** `example-app/build/outputs/apk/release/example-app-release.apk`

### With Gradle Wrapper
```bash
cd android
chmod +x gradlew
./gradlew :example-app:assembleRelease
```

## Installation

### From Android Studio
1. Open project root in Android Studio
2. Select `example-app` as run configuration
3. Press Shift+F10 (or Click Run)

### Manual APK Installation
```bash
adb install example-app/build/outputs/apk/release/example-app-release.apk
```

## Permissions Required

The app requests the following permissions:
- `ACCESS_FINE_LOCATION` - Precise location
- `ACCESS_COARSE_LOCATION` - Approximate location
- `ACCESS_BACKGROUND_LOCATION` - Background tracking
- `ACTIVITY_RECOGNITION` - Activity detection
- `FOREGROUND_SERVICE` - Persistent notifications
- `INTERNET` - Map tiles and location services

**User must grant these at runtime** (Android 6+)

## Usage

### 1. Start Tracking
- Toggle "Tracking Status" on Home screen
- Permissions will be requested if not granted

### 2. Create Geofence Zones
**Method A: Manual Entry**
- Tap "Add Zone" button
- Enter latitude, longitude, radius
- Confirm

**Method B: Map Selection**
- Tap "Open Map"
- Tap map to select location
- Adjust radius with slider
- Confirm creation

### 3. Monitor Zones
- View active zone count
- See tracking status
- Receive notifications on entry/exit

### 4. Customize Settings
- Enable/disable notifications
- Enable/disable battery optimization
- Control background tracking

## Example Coordinates

### San Francisco
- Latitude: 37.7749
- Longitude: -122.4194
- Suggested Radius: 1000m

### New York
- Latitude: 40.7128
- Longitude: -74.0060
- Suggested Radius: 1000m

### Los Angeles
- Latitude: 34.0522
- Longitude: -118.2437
- Suggested Radius: 1000m

## Build Configuration

### Gradle Properties
- minSdk: 24
- targetSdk: 34
- compileSdk: 34
- NDK: 25.1.8937393
- Java: 11

### Compose Configuration
- Kotlin Compiler Extension: 1.5.3
- Material Design: 3

## Performance

- APK Size: ~30-40 MB (release)
- Minimum Memory: 256 MB
- Battery Usage: 2-8% per hour (depends on activity)

## Testing

### Debug
```bash
./gradlew :example-app:installDebug
```

### Run Tests
```bash
./gradlew :example-app:connectedAndroidTest
```

### Take Screenshot
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png .
```

## Troubleshooting

### Location Permissions Not Granted
**Solution:**
- Check app permissions in device Settings
- Grant location and activity recognition
- Uninstall and reinstall app

### Map Not Loading
**Solution:**
- Ensure internet connection
- Check INTERNET permission
- Try zooming in/out
- Wait for tiles to load

### Geofence Not Triggering
**Solution:**
- Verify location services enabled
- Check location accuracy
- Ensure tracking is active
- Check notification settings

### APK Won't Install
**Solution:**
- Clear app cache: `adb shell pm clear com.placealertme.example`
- Uninstall previous version: `adb uninstall com.placealertme.example`
- Ensure Android version compatibility (24+)

## Development

### Add New Screen
1. Create `YourScreen.kt` in `ui/screens/`
2. Add Composable function
3. Add to navigation in `MainActivity.kt`

### Modify Theme
- Edit colors in `ui/theme/Theme.kt`
- Update strings in `res/values/strings.xml`

### Build Variants
- Debug: Debuggable, logging enabled
- Release: Obfuscated, optimized

## Release

### Signing
```bash
keytool -genkey -v -keystore release.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias placealertme
```

### Sign Release APK
```bash
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore release.keystore \
  example-app/build/outputs/apk/release/example-app-release-unsigned.apk \
  placealertme

zipalign -v 4 example-app/build/outputs/apk/release/example-app-release-unsigned.apk \
  example-app-release.apk
```

## Documentation

- [PlaceAlertMe Library](../../README.md)
- [Android Integration](../../ANDROID_LIBRARY_USAGE.md)
- [API Reference](../../API_REFERENCE.md)
- [Build Guide](../../BUILD.md)

## License

MIT License - See repository for details

## Support

- GitHub Issues: Report bugs and request features
- Examples: See code in `ui/screens/`
- Documentation: Read guides above

---

**Status:** ✅ Production Ready  
**Version:** 1.0.0  
**Android Version:** 24-34  
**Last Updated:** 2024-05-20
