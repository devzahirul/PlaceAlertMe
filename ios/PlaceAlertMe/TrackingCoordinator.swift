import Foundation
import CoreLocation
import CoreMotion

class TrackingCoordinator: NSObject {
    static let shared = TrackingCoordinator()

    private let locationManager: LocationManager
    private let activityManager: ActivityRecognitionManager
    private var isTrackingActive = false

    override init() {
        locationManager = LocationManager()
        activityManager = ActivityRecognitionManager()
        super.init()

        locationManager.delegate = self
        activityManager.delegate = self
    }

    func startTracking() {
        if isTrackingActive { return }

        locationManager.startTracking()
        activityManager.startActivityRecognition()
        isTrackingActive = true
    }

    func stopTracking() {
        if !isTrackingActive { return }

        locationManager.stopTracking()
        activityManager.stopActivityRecognition()
        isTrackingActive = false
    }

    func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        locationManager.addGeofenceZone(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }

    func clearGeofenceZones() {
        locationManager.clearGeofenceZones()
    }
}

extension TrackingCoordinator: LocationManagerDelegate {
    func locationManager(_ manager: LocationManager, didUpdate location: CLLocation, response: GeoEngineResponse) {
        NotificationCenter.default.post(
            name: NSNotification.Name("GeofenceStatusChanged"),
            object: nil,
            userInfo: [
                "isInside": response.isInsideZone,
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "distance": response.distanceMeters,
                "nextInterval": response.nextIntervalMs
            ]
        )
    }

    func locationManager(_ manager: LocationManager, didChangeZoneStatus isInside: Bool) {
        NotificationCenter.default.post(
            name: NSNotification.Name("GeofenceZoneStatusChanged"),
            object: nil,
            userInfo: ["isInside": isInside]
        )
    }
}

extension TrackingCoordinator: ActivityRecognitionDelegate {
    func activityRecognitionManager(_ manager: ActivityRecognitionManager, didDetectActivity activity: CMMotionActivity) {
        if ActivityRecognitionManager.isActivityStill(activity) {
            locationManager.pauseTracking()
        } else if ActivityRecognitionManager.isActivityMoving(activity) {
            locationManager.resumeTracking()
        }
    }
}
