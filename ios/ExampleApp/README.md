# PlaceAlertMe iOS Example App

A complete example iOS app demonstrating the PlaceAlertMe geofencing library with SwiftUI UI and MapKit integration.

## Features

✨ **SwiftUI Interface**
- Modern, clean user interface
- TabBar navigation for Home, Map, Settings
- Real-time tracking status display
- Interactive zone management

✨ **MapKit Integration**
- Interactive map for location selection
- Tap-to-select location picker
- Real-time radius visualization
- Zoom controls and map annotations

✨ **Geofencing Management**
- Create circular geofence zones
- Adjust radius dynamically (100-5000m)
- View active zones with coordinates
- Delete zones with swipe gesture
- Manual entry or map-based selection

✨ **Adaptive Tracking**
- Battery-efficient location updates
- Activity recognition support
- Speed-based interval adjustment
- Background location tracking

## Screens

### Home Screen
- Tracking status toggle (active/inactive)
- Zone statistics card
- Quick action buttons (Add Zone, Open Map)
- List of active zones with coordinates
- Swipe to delete zones

### Map Screen
- Interactive MapKit display
- Tap map to select location
- Real-time coordinate display
- Radius slider (100-5000m)
- Visual zone representation
- Confirm button to create zone

### Settings Screen
- Notifications toggle
- Background tracking toggle
- Battery optimization toggle
- App version and build info
- Feature descriptions
- Example coordinates (SF, NY, LA)
- Quick start guide

## Project Structure

```
ExampleApp/
├── Package.swift
├── Info.plist
├── README.md
├── Sources/
│   ├── PlaceAlertMeExampleApp.swift (Main app entry)
│   ├── ContentView.swift (Tab navigation)
│   ├── Screens/
│   │   ├── HomeScreen.swift
│   │   ├── MapScreen.swift
│   │   └── SettingsScreen.swift
│   └── Models/
│       └── (Data models included in main files)
```

## Dependencies

- **PlaceAlertMe** - Local geofencing library
- **SwiftUI** - UI framework
- **MapKit** - Map display
- **CoreLocation** - Location services (via PlaceAlertMe)
- **iOS 14+** - Minimum deployment target

## Building

### Via Xcode
1. Open project in Xcode
2. Select `ExampleApp` scheme
3. Select simulator or device
4. Press Cmd+R to run

### Via Swift Package Manager
```bash
cd ios/ExampleApp
swift build -c release
```

### Building for Device
1. Configure signing in Xcode
2. Select physical device in scheme
3. Press Cmd+R

## Installation

### From Xcode
1. Connect device via USB
2. Select device in scheme dropdown
3. Press Cmd+R to build and run

### Manual Build & Run
```bash
cd ios/ExampleApp
xcodebuild -scheme ExampleApp -destination 'platform=iOS,name=iPhone 15'
```

## Permissions Required

The app requests the following permissions (runtime):
- `NSLocationWhenInUseUsageDescription` - Precise location
- `NSLocationAlwaysAndWhenInUseUsageDescription` - Background tracking
- Background location mode - For persistent tracking

**User must grant these at runtime** in Settings → Privacy → Location

## Usage

### 1. Start Tracking
- Tap the toggle on Home screen
- Allow location permissions when prompted

### 2. Create Geofence Zones

**Method A: Manual Entry**
- Tap "Add Zone" button
- Enter latitude, longitude, radius
- Confirm

**Method B: Map Selection**
- Tap "Map" tab
- Tap map to select location
- Adjust radius with slider
- Tap "Confirm Zone"

### 3. Monitor Zones
- View active zone count
- See tracking status
- Receive notifications on entry/exit (if enabled)

### 4. Customize Settings
- Enable/disable notifications
- Enable/disable background tracking
- Configure battery optimization

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

### Deployment Target
- iOS: 14.0+
- Swift: 5.9+

### UI Framework
- SwiftUI
- MapKit

### Location Services
- CoreLocation (via PlaceAlertMe)
- Background modes enabled

## Performance

- App Size: ~50-60 MB (release build)
- Minimum Memory: 256 MB
- Battery Usage: 2-8% per hour (depends on activity)
- Location Accuracy: ~5-20 meters (depends on settings)

## Testing

### Manual Testing
1. Create zones with known coordinates
2. Move to zone boundaries
3. Verify entry/exit notifications
4. Check tracking status updates
5. Test background tracking

### Example Test Scenario
1. Create zone at (37.7749, -122.4194) with 1000m radius
2. Enable tracking
3. Simulate location change to zone center
4. Verify notification received

## Troubleshooting

### Location Permissions Not Granted
**Solution:**
- Check Settings → Privacy → Location
- Ensure "While Using" or "Always" is selected
- Restart app after granting permissions

### Map Not Loading
**Solution:**
- Ensure internet connection
- Check device is connected to network
- Try zooming in/out
- Restart app

### Geofence Not Triggering
**Solution:**
- Verify location services enabled
- Check location accuracy (needs GPS or network)
- Ensure tracking is active
- Check notification settings

### Zone Not Saved
**Solution:**
- Check app has storage permissions
- Ensure enough device storage
- Try creating zone again

## Development

### Add New Screen
1. Create `YourScreen.swift` in `Screens/`
2. Add Composable view
3. Add to TabView in `ContentView.swift`

### Modify UI Theme
- Edit colors in SwiftUI views
- Update Info.plist for app settings
- Modify font sizes in relevant screens

### Integrate Custom Features
1. Extend `AppViewModel` class
2. Add new published properties
3. Update UI to use new properties

## Release

### Archive for TestFlight
1. Select "Generic iOS Device"
2. Product → Archive
3. Distribute App
4. Select TestFlight
5. Upload to Apple

### App Store Submission
1. Create App ID in Apple Developer
2. Configure app capabilities
3. Build and archive
4. Submit for review

## Documentation

- [PlaceAlertMe Library](../../README.md)
- [iOS Integration Guide](../../IOS_LIBRARY_USAGE.md)
- [API Reference](../../API_REFERENCE.md)
- [Build Guide](../../BUILD.md)

## License

MIT License - See repository for details

## Support

- GitHub Issues: Report bugs and request features
- Documentation: See guides above
- Examples: Review code in Screens/

---

**Status:** ✅ Production Ready  
**Version:** 1.0.0  
**Minimum iOS:** 14.0+  
**Last Updated:** 2024-05-20
