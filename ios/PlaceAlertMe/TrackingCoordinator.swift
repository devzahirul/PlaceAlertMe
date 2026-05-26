import Foundation
import CoreLocation
import CoreMotion

internal class TrackingCoordinator: NSObject {
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

    func addGeofenceZone(id: String, name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        locationManager.addGeofenceZone(id: id, name: name,
                                         latitude: latitude, longitude: longitude,
                                         radiusMeters: radiusMeters)
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
                "isInside": response.isInsideAnyZone,
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "distance": response.distanceToNearestMeters,
                "nextInterval": response.nextIntervalMs
            ]
        )
    }

    func locationManager(_ manager: LocationManager, didTransition transition: ZoneTransition) {
        let notificationName: NSNotification.Name
        switch transition.type {
        case .enter: notificationName = NSNotification.Name("ZoneEnter")
        case .exit:  notificationName = NSNotification.Name("ZoneExit")
        }
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: [
                "zoneId": transition.zoneId,
                "zoneName": transition.zoneName,
                "distanceMeters": transition.distanceMeters,
                "timestampMs": transition.timestampMs
            ]
        )
    }
}

extension TrackingCoordinator: ActivityRecognitionDelegate {
    func activityRecognitionManager(_ manager: ActivityRecognitionManager, didDetectActivity activity: CMMotionActivity) {
        if activity.stationary {
            locationManager.activityScaleFactor = 3.0
        } else if activity.automotive {
            locationManager.activityScaleFactor = 0.5
        } else {
            locationManager.activityScaleFactor = 1.0
        }
    }
}
