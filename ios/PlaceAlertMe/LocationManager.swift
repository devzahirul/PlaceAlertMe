import Foundation

#if os(iOS)
import CoreLocation

internal protocol LocationManagerDelegate: AnyObject {
    func locationManager(_ manager: LocationManager, didUpdate location: CLLocation, response: GeoEngineResponse)
    func locationManager(_ manager: LocationManager, didTransition transition: ZoneTransition)
}
#endif

#if os(iOS)
internal class LocationManager: NSObject, CLLocationManagerDelegate {
    weak var delegate: LocationManagerDelegate?

    private let clLocationManager = CLLocationManager()
    private let geoEngineManager = GeoEngineManager.shared
    private var currentIntervalMs: Int64 = 10000
    private var updateTimer: Timer?
    var activityScaleFactor: Double = 1.0

    override init() {
        super.init()
        setupLocationManager()
    }

    private func setupLocationManager() {
        clLocationManager.delegate = self
        clLocationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        clLocationManager.pausesLocationUpdatesAutomatically = false
        clLocationManager.distanceFilter = 5
    }

    func requestLocationPermission() {
        if #available(iOS 14.0, *) {
            let status = clLocationManager.authorizationStatus
            if status == .notDetermined {
                clLocationManager.requestAlwaysAuthorization()
            }
        } else {
            clLocationManager.requestAlwaysAuthorization()
        }
    }

    func startTracking() {
        requestLocationPermission()
        clLocationManager.allowsBackgroundLocationUpdates = true
        let records = PlaceStore.shared.load()
        for record in records {
            geoEngineManager.addZone(id: record.id, name: record.name,
                                     latitude: record.latitude, longitude: record.longitude,
                                     radiusMeters: record.radiusMeters)
            registerCLRegion(id: record.id, latitude: record.latitude,
                             longitude: record.longitude, radiusMeters: record.radiusMeters)
        }
        clLocationManager.startUpdatingLocation()
    }

    func stopTracking() {
        clLocationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func pauseTracking() {
        clLocationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func resumeTracking() {
        clLocationManager.startUpdatingLocation()
    }

    func addGeofenceZone(id: String, name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        geoEngineManager.addZone(id: id, name: name,
                                 latitude: latitude, longitude: longitude,
                                 radiusMeters: radiusMeters)
        PlaceStore.shared.add(PlaceRecord(id: id, name: name,
                                          latitude: latitude, longitude: longitude,
                                          radiusMeters: radiusMeters))
        registerCLRegion(id: id, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }

    func clearGeofenceZones() {
        geoEngineManager.clearZones()
        PlaceStore.shared.clear()
        for region in clLocationManager.monitoredRegions {
            clLocationManager.stopMonitoring(for: region)
        }
    }

    private func registerCLRegion(id: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        guard clLocationManager.monitoredRegions.count < 20 else { return }
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let effectiveRadius = max(radiusMeters, 150.0)
        let region = CLCircularRegion(center: center, radius: effectiveRadius, identifier: id)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        clLocationManager.startMonitoring(for: region)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let speed = location.speed >= 0 ? location.speed : 0
        let accuracyMeters = location.horizontalAccuracy
        let timestampMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)

        let response = geoEngineManager.processLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedMps: speed,
            accuracyMeters: accuracyMeters,
            timestampMs: timestampMs
        )

        updateLocationAccuracy(basedOnDistance: response.distanceToNearestMeters)
        updateTrackingInterval(response.nextIntervalMs)

        for transition in response.transitions {
            delegate?.locationManager(self, didTransition: transition)
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

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        manager.requestLocation()
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

        if clLocationManager.desiredAccuracy != accuracy {
            clLocationManager.desiredAccuracy = accuracy
        }
    }

    private func updateTrackingInterval(_ newIntervalMs: Int64) {
        let scaledMs = Int64(Double(newIntervalMs) * activityScaleFactor)
        if scaledMs == currentIntervalMs { return }

        currentIntervalMs = scaledMs
        let intervalSeconds = Double(scaledMs) / 1000.0

        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            self?.clLocationManager.requestLocation()
        }
    }
}
#endif
