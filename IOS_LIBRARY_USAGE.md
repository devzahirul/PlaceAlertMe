# PlaceAlertMe iOS Library - Usage Guide

Complete guide to integrate PlaceAlertMe geofencing library into your iOS app.

## Installation

### Option 1: Swift Package Manager (Recommended)

1. In Xcode: **File** → **Add Packages**
2. Enter repository URL:
   ```
   https://github.com/devzahirul/PlaceAlertMe.git
   ```
3. Select version (e.g., 1.0.0+)
4. Choose your target and click **Add Package**

### Option 2: CocoaPods

Add to your `Podfile`:

```ruby
pod 'PlaceAlertMe', '~> 1.0.0'
```

Then run:
```bash
pod install
```

### Option 3: Manual Integration

1. Clone the repository
2. Drag `PlaceAlertMe` folder into your Xcode project
3. Add to **Target** → **Build Phases** → **Link Binary with Libraries**

## Permissions

Add required keys to `Info.plist`:

```xml
<!-- Location permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>PlaceAlertMe needs your location for geofencing</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>PlaceAlertMe needs constant location access for background geofencing</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>PlaceAlertMe needs your location at all times</string>

<!-- Motion activity permissions -->
<key>NSMotionUsageDescription</key>
<string>PlaceAlertMe uses motion data to optimize battery usage</string>
```

Or in code:

```swift
import InfoPlist

// Add to Info.plist
[
    "NSLocationWhenInUseUsageDescription": "PlaceAlertMe needs your location for geofencing",
    "NSLocationAlwaysAndWhenInUseUsageDescription": "PlaceAlertMe needs constant location access",
    "NSMotionUsageDescription": "PlaceAlertMe uses motion data for optimization"
]
```

## Quick Start

### Basic Usage

```swift
import PlaceAlertMe

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Initialize PlaceAlertMe
        PlaceAlertMe.shared.delegate = self
        
        // Start tracking
        PlaceAlertMe.shared.startTracking()
        
        // Add geofence zones
        PlaceAlertMe.shared.addGeofenceZone(
            latitude: 37.7749,    // San Francisco
            longitude: -122.4194,
            radiusMeters: 5000.0  // 5 km radius
        )
        
        return true
    }
}

extension AppDelegate: PlaceAlertMeDelegate {
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didUpdateGeofenceStatus status: GeofenceStatus
    ) {
        print("Location: (\(status.latitude), \(status.longitude))")
        print("Distance: \(status.distance)m")
        print("Next Update: \(status.nextIntervalMs)ms")
    }
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didChangeZoneStatus isInside: Bool
    ) {
        if isInside {
            print("📍 Entered zone")
        } else {
            print("📍 Exited zone")
        }
    }
}
```

### With SwiftUI

```swift
import SwiftUI
import PlaceAlertMe

@main
struct PlaceAlertMeApp: App {
    
    @StateObject private var locationModel = LocationModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationModel)
                .onAppear {
                    locationModel.startTracking()
                }
        }
    }
}

class LocationModel: NSObject, ObservableObject, PlaceAlertMeDelegate {
    
    @Published var currentStatus: GeofenceStatus?
    @Published var isInsideZone: Bool = false
    
    override init() {
        super.init()
        PlaceAlertMe.shared.delegate = self
    }
    
    func startTracking() {
        PlaceAlertMe.shared.startTracking()
        
        PlaceAlertMe.shared.addGeofenceZone(
            latitude: 37.7749,
            longitude: -122.4194,
            radiusMeters: 5000.0
        )
    }
    
    func stopTracking() {
        PlaceAlertMe.shared.stopTracking()
    }
    
    // MARK: - PlaceAlertMeDelegate
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didUpdateGeofenceStatus status: GeofenceStatus
    ) {
        DispatchQueue.main.async {
            self.currentStatus = status
        }
    }
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didChangeZoneStatus isInside: Bool
    ) {
        DispatchQueue.main.async {
            self.isInsideZone = isInside
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var locationModel: LocationModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("PlaceAlertMe")
                .font(.title)
            
            if let status = locationModel.currentStatus {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Status: \(status.isInside ? "INSIDE" : "OUTSIDE")")
                    Text("Latitude: \(status.latitude)")
                    Text("Longitude: \(status.longitude)")
                    Text("Distance: \(status.distance, specifier: "%.0f")m")
                    Text("Next Update: \(status.nextIntervalMs)ms")
                }
                .font(.caption)
            }
            
            Spacer()
            
            Button(action: {
                locationModel.stopTracking()
            }) {
                Text("Stop Tracking")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
```

## API Reference

### PlaceAlertMe Class

Main singleton class for geofencing functionality.

```swift
public class PlaceAlertMe {
    public static let shared: PlaceAlertMe
    
    public weak var delegate: PlaceAlertMeDelegate?
    
    public func startTracking()
    public func stopTracking()
    public func addGeofenceZone(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    )
    public func clearGeofenceZones()
}
```

#### Methods

**startTracking()**
```swift
public func startTracking()
```
- Requests location permission if needed
- Enables background location updates
- Starts activity monitoring
- Safe to call multiple times

**stopTracking()**
```swift
public func stopTracking()
```
- Stops location updates
- Stops activity monitoring

**addGeofenceZone**
```swift
public func addGeofenceZone(
    latitude: Double,
    longitude: Double,
    radiusMeters: Double
)
```
- Adds circular geofence zone
- Can add multiple zones
- Parameters:
  - `latitude`: -90 to 90
  - `longitude`: -180 to 180
  - `radiusMeters`: > 0

**clearGeofenceZones()**
```swift
public func clearGeofenceZones()
```
- Removes all zones

### PlaceAlertMeDelegate Protocol

```swift
public protocol PlaceAlertMeDelegate: AnyObject {
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didUpdateGeofenceStatus status: GeofenceStatus
    )
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didChangeZoneStatus isInside: Bool
    )
}
```

**didUpdateGeofenceStatus**
- Called on each location update
- Provides current location and distance to zones
- Recommended update interval included

**didChangeZoneStatus**
- Called only on zone entry/exit
- Provides boolean indicating if inside zone

### GeofenceStatus Struct

```swift
public struct GeofenceStatus {
    public let isInside: Bool
    public let latitude: Double
    public let longitude: Double
    public let distance: Double
    public let nextIntervalMs: Int64
    public var nextIntervalSeconds: TimeInterval { get }
}
```

## Advanced Examples

### Multiple Zones

```swift
let tracker = PlaceAlertMe.shared
tracker.startTracking()

// Add multiple zones
tracker.addGeofenceZone(37.7749, -122.4194, 5000.0)   // SF
tracker.addGeofenceZone(34.0522, -118.2437, 5000.0)   // LA
tracker.addGeofenceZone(40.7128, -74.0060, 5000.0)    // NYC
```

### Distance-Based Actions

```swift
func placeAlertMe(
    _ tracker: PlaceAlertMe,
    didUpdateGeofenceStatus status: GeofenceStatus
) {
    switch status.distance {
    case 0..<100:
        handleVeryClose()
    case 100..<500:
        handleNearby()
    case 500..<2000:
        handleFar()
    default:
        handleVeryFar()
    }
}
```

### Conditional Tracking

```swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume tracking when app becomes active
        PlaceAlertMe.shared.startTracking()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Keep tracking in background
        // (geofencing automatically optimizes)
    }
}
```

### Background Notifications

```swift
import UserNotifications

extension AppDelegate: PlaceAlertMeDelegate {
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didChangeZoneStatus isInside: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Zone Status Changed"
        content.body = isInside ? "You entered the zone" : "You left the zone"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
```

### Location Logging

```swift
import os.log

class LocationLogger: NSObject, PlaceAlertMeDelegate {
    
    private let logger = Logger(subsystem: "com.app.location", category: "tracking")
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didUpdateGeofenceStatus status: GeofenceStatus
    ) {
        self.logger.debug("""
        Location Update:
        - Position: (\(status.latitude), \(status.longitude))
        - Inside Zone: \(status.isInside)
        - Distance: \(status.distance, privacy: .public)m
        - Next Interval: \(status.nextIntervalMs, privacy: .public)ms
        """)
    }
    
    func placeAlertMe(
        _ tracker: PlaceAlertMe,
        didChangeZoneStatus isInside: Bool
    ) {
        self.logger.info("Zone Status: \(isInside ? "INSIDE" : "OUTSIDE")")
    }
}
```

## Troubleshooting

### Location Permission Denied

**Issue:** Tracking doesn't start
**Solution:**
1. Check `Info.plist` has required keys
2. Check that user grants permission in settings
3. Try again after granting permission in Settings

### Delegate Not Called

**Issue:** `PlaceAlertMeDelegate` methods not invoked
**Solution:**
1. Ensure `delegate` is set to non-nil object
2. Verify `startTracking()` was called
3. Check that location permission is granted
4. Ensure object with delegate lives long enough

### Memory Issues

**Issue:** Memory usage increases over time
**Solution:**
1. Ensure `stopTracking()` is called when done
2. Check that delegate object is not retained by tracking
3. Clear zones with `clearGeofenceZones()` if adding many
4. Profile with Xcode Instruments to find leaks

### Location Not Updating

**Issue:** No location updates received
**Solution:**
1. Verify location services enabled on device
2. Check location permission is "Always" (not "While Using")
3. Add at least one zone before starting tracking
4. Ensure device is moving (background updates are throttled when still)

## Performance Optimization

1. **Limit Zones:** Keep < 50 zones for optimal performance
2. **Update Intervals:** Library automatically adjusts based on speed
3. **Activity Detection:** Motion detection automatically pauses updates
4. **Clear Zones:** Remove unused zones with `clearGeofenceZones()`
5. **Delegate Efficiency:** Keep delegate methods lightweight

## Best Practices

1. **Permission Timing:** Request location permission at appropriate time
2. **Background Mode:** Enable "Location Updates" in Capabilities
3. **Error Handling:** Always check results from location permission request
4. **Memory Management:** Use weak references in delegates
5. **Testing:** Test on real device for accurate location behavior

## Sample Project

See `ios/PlaceAlertMe/SampleViewController.swift` for complete example.

## Requirements

- iOS 13.0+
- Swift 5.5+
- Xcode 14+

## License

MIT License - See repository for details
