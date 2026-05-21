import Foundation

#if os(iOS)
import CoreLocation
import CoreMotion

internal class TrackingCoordinator: NSObject {
    static let shared = TrackingCoordinator()

    private let locationManager: LocationManager
    private let activityManager: ActivityRecognitionManager
    private let systemGeofenceManager: SystemGeofenceManager

    /// Zones registered with the coordinator. Keyed by `GeoZone.id`.
    private var zonesById: [String: GeoZone] = [:]

    private var isTrackingActive = false

    override init() {
        locationManager = LocationManager()
        activityManager = ActivityRecognitionManager()
        systemGeofenceManager = SystemGeofenceManager()
        super.init()

        locationManager.delegate = self
        activityManager.delegate = self
        systemGeofenceManager.delegate = self
    }

    // MARK: - Live tracking

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

    // MARK: - Legacy zone API (no IDs)
    //
    // Kept for backward compatibility. New code should use the
    // `GeoZone`-based API below.

    func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        let legacyId = "legacy:\(latitude):\(longitude):\(radiusMeters)"
        addZone(GeoZone(
            id: legacyId,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        ))
    }

    func clearGeofenceZones() {
        clearAllZones()
    }

    // MARK: - Zone management (new ID-based API)

    func addZone(_ zone: GeoZone) {
        zonesById[zone.id] = zone
        syncZonesToEngines()
    }

    func removeZone(id: String) {
        zonesById.removeValue(forKey: id)
        syncZonesToEngines()
    }

    func setZones(_ zones: [GeoZone]) {
        zonesById = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })
        syncZonesToEngines()
    }

    func clearAllZones() {
        zonesById.removeAll()
        syncZonesToEngines()
    }

    var allZones: [GeoZone] {
        Array(zonesById.values)
    }

    // MARK: - Background (terminated-state) monitoring

    func enableBackgroundMonitoring(maxRegions: Int) {
        systemGeofenceManager.enable(maxRegions: maxRegions)
    }

    func disableBackgroundMonitoring() {
        systemGeofenceManager.disable()
    }

    var isBackgroundMonitoringEnabled: Bool {
        systemGeofenceManager.isEnabled
    }

    // MARK: - Internal

    /// Push the current zone set down to both the C++ engine (live precise
    /// tracking) and the system geofence manager (terminated-state wake-up).
    private func syncZonesToEngines() {
        let zones = Array(zonesById.values)

        // 1. C++ engine — used by the continuous-GPS path for high-precision
        //    in-app status and adaptive update intervals.
        let cppEngine = GeoEngineManager.shared
        cppEngine.clearZones()
        for zone in zones {
            cppEngine.addZone(zone)
        }

        // 2. System geofence — for terminated-state survival.
        systemGeofenceManager.updateZones(zones)
    }

    /// Idempotent per-zone state transition from platform-native geofence
    /// events. The C++ engine owns dedup + trigger filtering so live GPS and
    /// system region events share one decision layer.
    private func transitionZone(_ zone: GeoZone, isInside: Bool) {
        guard let transition = GeoEngineManager.shared.updateZoneState(
            zoneId: zone.id,
            isInside: isInside
        ) else { return }

        postTransition(transition)
    }

    private func postTransition(_ transition: GeoEngineZoneTransition) {
        guard let zone = zonesById[transition.zoneId] else { return }

        let name = transition.isInside ? Self.didEnterZoneNotification : Self.didExitZoneNotification
        NotificationCenter.default.post(
            name: name,
            object: nil,
            userInfo: Self.encodeZone(zone)
        )
    }

    static let didEnterZoneNotification = NSNotification.Name("PlaceAlertMeDidEnterZone")
    static let didExitZoneNotification = NSNotification.Name("PlaceAlertMeDidExitZone")

    static func encodeZone(_ zone: GeoZone) -> [String: Any] {
        return [
            "id": zone.id,
            "latitude": zone.latitude,
            "longitude": zone.longitude,
            "radiusMeters": zone.radiusMeters,
            "notifyOnEntry": zone.notifyOnEntry,
            "notifyOnExit": zone.notifyOnExit,
        ]
    }
}

// MARK: - LocationManagerDelegate (continuous GPS path)

extension TrackingCoordinator: LocationManagerDelegate {
    func locationManager(_ manager: LocationManager, didUpdate location: CLLocation, response: GeoEngineResponse) {
        // Global "any zone" notification (legacy listeners).
        NotificationCenter.default.post(
            name: NSNotification.Name("GeofenceStatusChanged"),
            object: nil,
            userInfo: [
                "isInside": response.isInsideZone,
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "distance": response.distanceMeters,
                "nextInterval": response.nextIntervalMs,
            ]
        )

        // Per-zone transitions are already computed by the shared C++ engine.
        for transition in response.transitions {
            postTransition(transition)
        }
    }

    func locationManager(_ manager: LocationManager, didChangeZoneStatus isInside: Bool) {
        NotificationCenter.default.post(
            name: NSNotification.Name("GeofenceZoneStatusChanged"),
            object: nil,
            userInfo: ["isInside": isInside]
        )
    }
}

// MARK: - ActivityRecognitionDelegate (battery-saver pause/resume)

extension TrackingCoordinator: ActivityRecognitionDelegate {
    func activityRecognitionManager(_ manager: ActivityRecognitionManager, didDetectActivity activity: CMMotionActivity) {
        if ActivityRecognitionManager.isActivityStill(activity) {
            locationManager.pauseTracking()
        } else if ActivityRecognitionManager.isActivityMoving(activity) {
            locationManager.resumeTracking()
        }
    }
}

// MARK: - SystemGeofenceManagerDelegate (terminated-state wake-up)

extension TrackingCoordinator: SystemGeofenceManagerDelegate {
    func systemGeofenceManager(_ manager: SystemGeofenceManager, didEnter zone: GeoZone) {
        transitionZone(zone, isInside: true)
    }

    func systemGeofenceManager(_ manager: SystemGeofenceManager, didExit zone: GeoZone) {
        transitionZone(zone, isInside: false)
    }
}
#endif
