import Foundation

#if os(iOS)
import CoreLocation

internal protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdate location: CLLocation, response: GeoEngineResponse)
    func locationManager(_ manager: LocationManager, didChangeZoneStatus isInside: Bool)
}
#endif

#if os(iOS)
internal class LocationManager: NSObject, CLLocationManagerDelegate {
    weak var delegate: LocationManagerDelegate?

    private let locationManager = CLLocationManager()
    private let geoEngineManager = GeoEngineManager.shared
    private var currentIntervalMs: Int64 = 10000
    private var lastZoneStatus = false
    private var updateTimer: Timer?

    override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.distanceFilter = 5
    }

    func requestLocationPermission() {
        if #available(iOS 14.0, *) {
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestAlwaysAndWhenInUseAuthorization()
            }
        } else {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func startTracking() {
        requestLocationPermission()
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func pauseTracking() {
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func resumeTracking() {
        locationManager.startUpdatingLocation()
    }

    func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        geoEngineManager.addZone(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }

    func clearGeofenceZones() {
        geoEngineManager.clearZones()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let speed = location.speed >= 0 ? location.speed : 0
        let response = geoEngineManager.processLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedMps: speed
        )

        updateLocationAccuracy(basedOnDistance: response.distanceMeters)
        updateTrackingInterval(response.nextIntervalMs)

        if response.isInsideZone != lastZoneStatus {
            lastZoneStatus = response.isInsideZone
            delegate?.locationManager(self, didChangeZoneStatus: response.isInsideZone)
        }

        delegate?.locationManager(self, didUpdate: location, response: response)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            let status = manager.authorizationStatus
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                startTracking()
            }
        }
    }

    // MARK: - Adaptive Tracking

    private func updateLocationAccuracy(basedOnDistance distance: Double) {
        let accuracy: CLLocationAccuracy

        if distance < 500 {
            accuracy = kCLLocationAccuracyBestForNavigation
        } else if distance < 1000 {
            accuracy = kCLLocationAccuracyBest
        } else if distance < 5000 {
            accuracy = kCLLocationAccuracyNearestTenMeters
        } else {
            accuracy = kCLLocationAccuracyHundredMeters
        }

        if locationManager.desiredAccuracy != accuracy {
            locationManager.desiredAccuracy = accuracy
        }
    }

    private func updateTrackingInterval(_ newIntervalMs: Int64) {
        if newIntervalMs == currentIntervalMs {
            return
        }

        currentIntervalMs = newIntervalMs
        let intervalSeconds = Double(newIntervalMs) / 1000.0

        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.locationManager.requestLocation()
        }
    }
}
#endif
