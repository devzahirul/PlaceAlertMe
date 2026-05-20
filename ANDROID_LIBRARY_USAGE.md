# PlaceAlertMe Android Library - Usage Guide

Complete guide to integrate PlaceAlertMe geofencing library into your Android app.

## Installation

### 1. Add JitPack Repository

In your project's `settings.gradle` (or `build.gradle` for older projects):

```gradle
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
```

### 2. Add Dependency

In your app's `build.gradle`:

```gradle
dependencies {
    implementation 'com.github.devzahirul:PlaceAlertMe:1.0.0'
}
```

Or if you want to depend on just the Android library:

```gradle
dependencies {
    implementation 'com.placealertme:geo-engine:1.0.0'
}
```

## Permissions

Add required permissions to `AndroidManifest.xml`:

```xml
<!-- Location Permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Activity Recognition -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />

<!-- Foreground Service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Internet for Google Play Services -->
<uses-permission android:name="android.permission.INTERNET" />
```

## Request Runtime Permissions

For Android 6+ (API 23+), request permissions at runtime:

```kotlin
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.pm.PackageManager

// Check if permissions are granted
val hasLocationPermission = ContextCompat.checkSelfPermission(
    this,
    Manifest.permission.ACCESS_FINE_LOCATION
) == PackageManager.PERMISSION_GRANTED

if (!hasLocationPermission) {
    ActivityCompat.requestPermissions(
        this,
        arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            Manifest.permission.ACTIVITY_RECOGNITION
        ),
        PERMISSION_REQUEST_CODE
    )
}

override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    
    if (requestCode == PERMISSION_REQUEST_CODE) {
        if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            // Start tracking after permissions granted
            tracker.startTracking()
        }
    }
}

companion object {
    private const val PERMISSION_REQUEST_CODE = 100
}
```

## Quick Start

### Basic Usage

```kotlin
import com.placealertme.geofence.GeoTracker

class MainActivity : AppCompatActivity() {
    
    private lateinit var tracker: GeoTracker
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // Initialize tracker
        tracker = GeoTracker(this)
        
        // Start tracking
        tracker.startTracking()
        
        // Add geofence zones
        tracker.addGeofenceZone(
            latitude = 37.7749,    // San Francisco
            longitude = -122.4194,
            radiusMeters = 5000.0  // 5 km radius
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        tracker.stopTracking()
    }
}
```

### Listen for Zone Changes

```kotlin
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    
    private val zoneStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val isInside = intent.getBooleanExtra(
                GeoTracker.EXTRA_IS_INSIDE, 
                false
            )
            val distance = intent.getDoubleExtra(
                GeoTracker.EXTRA_DISTANCE, 
                0.0
            )
            val nextInterval = intent.getLongExtra(
                GeoTracker.EXTRA_NEXT_INTERVAL, 
                10000L
            )
            
            val message = buildString {
                append("Status: ${if (isInside) "INSIDE" else "OUTSIDE"}\n")
                append("Distance: $distance meters\n")
                append("Next Update: ${nextInterval}ms")
            }
            
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        // Register receiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                zoneStatusReceiver,
                IntentFilter(GeoTracker.ACTION_ZONE_STATUS_CHANGED),
                ContextCompat.RECEIVER_EXPORTED
            )
        } else {
            registerReceiver(
                zoneStatusReceiver,
                IntentFilter(GeoTracker.ACTION_ZONE_STATUS_CHANGED)
            )
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(zoneStatusReceiver)
    }
}
```

## API Reference

### GeoTracker Class

```kotlin
class GeoTracker(context: Context)
```

#### Methods

**startTracking()**
```kotlin
fun startTracking()
```
- Starts location tracking and activity recognition
- Shows persistent notification
- Safe to call multiple times

**stopTracking()**
```kotlin
fun stopTracking()
```
- Stops all tracking
- Removes notification
- Stops service

**addGeofenceZone**
```kotlin
fun addGeofenceZone(
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
```kotlin
fun clearGeofenceZones()
```
- Removes all zones

**getZoneCount(): Int**
```kotlin
fun getZoneCount(): Int
```
- Returns current number of zones

**pauseTracking()**
```kotlin
fun pauseTracking()
```
- Pauses location updates
- Service remains running
- Activity recognition continues

**resumeTracking()**
```kotlin
fun resumeTracking()
```
- Resumes location updates

### Broadcast Constants

**ACTION_ZONE_STATUS_CHANGED**
```kotlin
GeoTracker.ACTION_ZONE_STATUS_CHANGED
// = "com.placealertme.ZONE_STATUS_CHANGED"
```

**Broadcast Extras**
```kotlin
// Boolean - location is inside zone
GeoTracker.EXTRA_IS_INSIDE

// Double - distance to zone in meters
GeoTracker.EXTRA_DISTANCE

// Long - next update interval in ms
GeoTracker.EXTRA_NEXT_INTERVAL

// Double - current latitude
GeoTracker.EXTRA_LATITUDE

// Double - current longitude
GeoTracker.EXTRA_LONGITUDE
```

## Advanced Examples

### Multiple Zones

```kotlin
val tracker = GeoTracker(this)
tracker.startTracking()

// Add multiple zones
tracker.addGeofenceZone(37.7749, -122.4194, 5000.0)   // SF
tracker.addGeofenceZone(34.0522, -118.2437, 5000.0)   // LA
tracker.addGeofenceZone(40.7128, -74.0060, 5000.0)    // NYC

// Check count
val count = tracker.getZoneCount()
println("Tracking $count zones")

// Clear all when done
tracker.clearGeofenceZones()
```

### Conditional Tracking

```kotlin
class LocationAwareActivity : AppCompatActivity() {
    
    private lateinit var tracker: GeoTracker
    
    override fun onResume() {
        super.onResume()
        // Resume tracking when app is visible
        tracker.resumeTracking()
    }
    
    override fun onPause() {
        super.onPause()
        // Pause tracking when app goes background
        tracker.pauseTracking()
    }
}
```

### Integration with ViewModel

```kotlin
import androidx.lifecycle.ViewModel
import androidx.lifecycle.AndroidViewModel
import android.app.Application

class LocationViewModel(app: Application) : AndroidViewModel(app) {
    
    private val tracker = GeoTracker(app)
    
    fun startTracking() {
        tracker.startTracking()
    }
    
    fun stopTracking() {
        tracker.stopTracking()
    }
    
    fun addZone(lat: Double, lon: Double, radius: Double) {
        tracker.addGeofenceZone(lat, lon, radius)
    }
    
    override fun onCleared() {
        super.onCleared()
        tracker.stopTracking()
    }
}

// In Activity
class MainActivity : AppCompatActivity() {
    private val viewModel: LocationViewModel by viewModels()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        viewModel.startTracking()
        viewModel.addZone(37.7749, -122.4194, 5000.0)
    }
}
```

### Manual Interval Control

```kotlin
// Listen for interval changes
val receiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val nextInterval = intent.getLongExtra(
            GeoTracker.EXTRA_NEXT_INTERVAL,
            10000L
        )
        
        // Do something based on interval
        when {
            nextInterval < 3000 -> Log.d("GEO", "Fast movement detected")
            nextInterval in 3000..30000 -> Log.d("GEO", "Normal movement")
            nextInterval > 30000 -> Log.d("GEO", "Slow movement or far from zone")
        }
    }
}

registerReceiver(
    receiver,
    IntentFilter(GeoTracker.ACTION_ZONE_STATUS_CHANGED)
)
```

## Troubleshooting

### Location Updates Not Starting

**Issue:** Geofence zone status not changing
**Solution:**
1. Verify location permissions are granted
2. Check that zones were added with valid coordinates
3. Ensure `startTracking()` was called
4. Check if device location services are enabled

### Crashes on Activity Start

**Issue:** `ExceptionInInitializerError` or JNI error
**Solution:**
1. Ensure native library (.so file) is properly built
2. Verify NDK version matches build.gradle
3. Check that `targetSdk` is 34 or lower
4. Clean and rebuild project: `./gradlew clean build`

### High Battery Drain

**Issue:** Battery drains quickly
**Solution:**
1. Reduce number of zones (recommended: < 50)
2. Ensure device is being detected as STILL when not moving
3. Check location accuracy setting
4. Verify activity recognition permission is granted
5. Use `pauseTracking()` when tracking not needed

### Broadcast Not Received

**Issue:** `ACTION_ZONE_STATUS_CHANGED` broadcasts not received
**Solution:**
1. Verify receiver is registered before tracking starts
2. Use `ContextCompat.RECEIVER_EXPORTED` on Android 12+
3. Check that action string matches exactly
4. Ensure app has foreground focus (broadcast is local)

## Performance Tips

1. **Limit Zones:** Keep < 50 zones for optimal performance
2. **Batch Updates:** Library already batches via FusedLocationProviderClient
3. **Pause When Not Needed:** Use `pauseTracking()` when app is backgrounded
4. **Activity Detection:** Activity recognition automatically reduces updates when still
5. **Clear Old Zones:** Remove unused zones with `clearGeofenceZones()`

## License

MIT License - See repository for details
