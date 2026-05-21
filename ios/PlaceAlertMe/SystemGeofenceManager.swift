import Foundation

#if os(iOS)
import CoreLocation

internal protocol SystemGeofenceManagerDelegate: AnyObject {
    func systemGeofenceManager(_ manager: SystemGeofenceManager, didEnter zone: GeoZone)
    func systemGeofenceManager(_ manager: SystemGeofenceManager, didExit zone: GeoZone)
}

/// Wraps iOS's native `CLCircularRegion` monitoring + significant-location
/// changes so the host app can be woken from terminated state on zone
/// entry/exit.
///
/// iOS hard-limits monitored regions to 20 per app. When more than 20
/// `GeoZone`s are registered, this manager registers only the nearest 20
/// to the last known location. As the user moves more than 500 m
/// (significant-location-change threshold), it re-evaluates which 20 to
/// monitor.
///
/// Requirements (Info.plist):
///   • `NSLocationAlwaysAndWhenInUseUsageDescription`
///   • `UIBackgroundModes` contains `location`
///
/// Requirements (permission):
///   • User must grant **Always** authorization. `When In Use` does NOT
///     fire region events when the app is terminated.
internal final class SystemGeofenceManager: NSObject, CLLocationManagerDelegate {
    weak var delegate: SystemGeofenceManagerDelegate?

    /// Hard ceiling enforced by iOS.
    static let iosMaxRegionsPerApp = 20

    private let locationManager = CLLocationManager()
    private var allZones: [String: GeoZone] = [:]
    private(set) var maxRegions: Int = 20
    private(set) var isEnabled: Bool = false
    private var lastSignificantLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           modes.contains("location") {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Start monitoring. The first 20 nearest zones to the last known
    /// location (or just the first 20 if no location yet) will be
    /// registered with iOS. Significant-location-change monitoring is
    /// also started so we can rotate the monitored set as the user moves.
    func enable(maxRegions: Int) {
        self.maxRegions = min(maxRegions, Self.iosMaxRegionsPerApp)
        self.isEnabled = true

        locationManager.startMonitoringSignificantLocationChanges()
        if lastSignificantLocation == nil {
            // Get a current location once to seed the nearest-N picker.
            locationManager.requestLocation()
        }
        refreshMonitoredRegions()
    }

    func disable() {
        isEnabled = false
        locationManager.stopMonitoringSignificantLocationChanges()
        clearAllMonitoredRegions()
    }

    /// Replace the full set of zones. Re-evaluates monitored regions
    /// immediately if monitoring is currently enabled.
    func updateZones(_ zones: [GeoZone]) {
        allZones = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })
        if isEnabled {
            refreshMonitoredRegions()
        }
    }

    /// Lookup a zone by the iOS-side identifier (used when iOS wakes us
    /// for a region event and we only have `region.identifier`).
    func zone(forIdentifier id: String) -> GeoZone? {
        allZones[id]
    }

    // MARK: - Region Management

    private func refreshMonitoredRegions() {
        clearAllMonitoredRegions()

        for zone in nearestZones(maxCount: maxRegions) {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude),
                radius: zone.radiusMeters,
                identifier: zone.id
            )
            region.notifyOnEntry = zone.notifyOnEntry
            region.notifyOnExit = zone.notifyOnExit
            locationManager.startMonitoring(for: region)
            // Force an immediate state check so we get an enter callback if
            // the user is already inside this zone at the moment of
            // registration (otherwise iOS only fires on the next crossing).
            locationManager.requestState(for: region)
        }
    }

    private func nearestZones(maxCount: Int) -> [GeoZone] {
        let zones = Array(allZones.values)
        guard let here = lastSignificantLocation else {
            return Array(zones.prefix(maxCount))
        }

        let nearest = GeoEngineManager.shared.nearestZoneIds(
            latitude: here.coordinate.latitude,
            longitude: here.coordinate.longitude,
            maxCount: maxCount
        )
        let ordered = nearest.compactMap { allZones[$0.zoneId] }
        if !ordered.isEmpty {
            return ordered
        }

        let sorted = zones.sorted { a, b in
            here.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude)) <
            here.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }
        return Array(sorted.prefix(maxCount))
    }

    /// CLLocationManager.monitoredRegions persists across app launches.
    /// Clearing the OS-side set + our internal set keeps the two in sync.
    private func clearAllMonitoredRegions() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let zone = allZones[region.identifier] else {
            print("[PlaceAlertMe.SystemGeofence] entered unknown region \(region.identifier)")
            return
        }
        delegate?.systemGeofenceManager(self, didEnter: zone)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let zone = allZones[region.identifier] else { return }
        delegate?.systemGeofenceManager(self, didExit: zone)
    }

    /// `requestState(for:)` fires this immediately after a region is
    /// registered. We use it to catch the "already inside" case.
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let zone = allZones[region.identifier] else { return }
        switch state {
        case .inside:
            delegate?.systemGeofenceManager(self, didEnter: zone)
        case .outside:
            // Only fire didExit if we explicitly thought we were inside.
            // For a fresh registration we can't tell — don't spam exit
            // events for zones the user was never inside.
            break
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Re-evaluate which 20 to monitor only when we've moved meaningfully.
        if let last = lastSignificantLocation,
           !GeoEngineManager.shared.hasMovedSignificantly(
               fromLatitude: last.coordinate.latitude,
               fromLongitude: last.coordinate.longitude,
               toLatitude: location.coordinate.latitude,
               toLongitude: location.coordinate.longitude,
               thresholdMeters: 500
           ) {
            return
        }
        lastSignificantLocation = location
        if isEnabled {
            refreshMonitoredRegions()
        }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("[PlaceAlertMe.SystemGeofence] monitoring failed for \(region?.identifier ?? "?"): \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[PlaceAlertMe.SystemGeofence] location error: \(error.localizedDescription)")
    }
}
#endif
