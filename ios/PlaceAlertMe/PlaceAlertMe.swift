import Foundation

#if os(iOS)
/// Public API for PlaceAlertMe geofencing.
///
/// PlaceAlertMe operates in two complementary layers:
///
/// 1. **Live tracker** — continuous GPS + activity recognition
///    pause/resume + a C++ geofence engine. Used whenever the host app
///    is alive (foreground or background). High precision, sub-meter
///    distance updates suitable for live "you are X meters away" UIs.
///
/// 2. **System geofence monitor** — opt-in iOS-native CLCircularRegion
///    monitoring. Once enabled with `enableBackgroundMonitoring()`,
///    iOS itself watches up to 20 of the nearest zones and wakes the
///    host app on entry/exit even when the app has been terminated by
///    the user or the system. The 20-zone limit is enforced by iOS;
///    PlaceAlertMe automatically rotates which 20 are monitored as the
///    user moves significantly (>500 m).
///
/// Both layers feed the same `didEnter`/`didExit` delegate callbacks
/// through a dedupe layer, so a single zone transition produces exactly
/// one callback regardless of which layer detected it.
public class PlaceAlertMe {
    public static let shared = PlaceAlertMe()

    private let coordinator = TrackingCoordinator.shared
    public weak var delegate: PlaceAlertMeDelegate?

    private init() {
        setupNotificationListeners()
    }

    // MARK: - Live tracking

    /// Start the continuous-GPS + activity-recognition tracker.
    /// Requires location permission (at least When-in-Use) granted first.
    public func startTracking() {
        coordinator.startTracking()
    }

    /// Stop the live tracker. Does NOT disable background monitoring —
    /// call `disableBackgroundMonitoring()` for that.
    public func stopTracking() {
        coordinator.stopTracking()
    }

    // MARK: - Zone management (new ID-based API)

    /// Add or replace a single zone (matched by `id`).
    public func setZone(_ zone: GeoZone) {
        coordinator.addZone(zone)
    }

    /// Replace the entire set of zones.
    public func setZones(_ zones: [GeoZone]) {
        coordinator.setZones(zones)
    }

    /// Remove a zone by id. No-op if no zone with that id exists.
    public func removeZone(id: String) {
        coordinator.removeZone(id: id)
    }

    /// Remove all zones from both engines.
    public func clearZones() {
        coordinator.clearAllZones()
    }

    /// Currently registered zones.
    public var zones: [GeoZone] {
        coordinator.allZones
    }

    // MARK: - Background (terminated-state) monitoring

    /// Begin iOS-native `CLCircularRegion` monitoring. Once enabled,
    /// the host app will be woken from terminated state for
    /// entry/exit events on any monitored zone.
    ///
    /// - Parameter maxRegions: Maximum number of zones to register with
    ///   iOS. Clamped to 20 (the iOS per-app hard ceiling). When more
    ///   `GeoZone`s exist than `maxRegions`, the nearest ones to the
    ///   user's current location are monitored and the set is rotated
    ///   as the user moves > 500 m.
    ///
    /// Requirements:
    ///   * Info.plist must include `NSLocationAlwaysAndWhenInUseUsageDescription`
    ///     and `UIBackgroundModes` containing `location`.
    ///   * User must grant **Always** authorization. With *When in Use*,
    ///     region events only fire while the app is in foreground or
    ///     background — NOT when terminated.
    public func enableBackgroundMonitoring(maxRegions: Int = 20) {
        coordinator.enableBackgroundMonitoring(maxRegions: maxRegions)
    }

    /// Stop iOS-native region monitoring. The live tracker is unaffected.
    public func disableBackgroundMonitoring() {
        coordinator.disableBackgroundMonitoring()
    }

    public var isBackgroundMonitoringEnabled: Bool {
        coordinator.isBackgroundMonitoringEnabled
    }

    // MARK: - Legacy API (backward compatible)
    //
    // Existing call-sites continue to work. New code should prefer
    // `setZone(_:)` / `setZones(_:)` so it gets per-zone callbacks.

    public func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        coordinator.addGeofenceZone(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }

    public func clearGeofenceZones() {
        coordinator.clearGeofenceZones()
    }

    // MARK: - Internal: notification → delegate bridge

    private func setupNotificationListeners() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(onGeofenceStatusChanged(_:)),
                       name: NSNotification.Name("GeofenceStatusChanged"), object: nil)
        nc.addObserver(self, selector: #selector(onGeofenceZoneStatusChanged(_:)),
                       name: NSNotification.Name("GeofenceZoneStatusChanged"), object: nil)
        nc.addObserver(self, selector: #selector(onDidEnterZone(_:)),
                       name: TrackingCoordinator.didEnterZoneNotification, object: nil)
        nc.addObserver(self, selector: #selector(onDidExitZone(_:)),
                       name: TrackingCoordinator.didExitZoneNotification, object: nil)
    }

    @objc private func onGeofenceStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let status = GeofenceStatus(
                isInside: userInfo["isInside"] as? Bool ?? false,
                latitude: userInfo["latitude"] as? Double ?? 0,
                longitude: userInfo["longitude"] as? Double ?? 0,
                distance: userInfo["distance"] as? Double ?? 0,
                nextIntervalMs: userInfo["nextInterval"] as? Int64 ?? 10000
            )
            self.delegate?.placeAlertMe(self, didUpdateGeofenceStatus: status)
        }
    }

    @objc private func onGeofenceZoneStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isInside = userInfo["isInside"] as? Bool ?? false
            self.delegate?.placeAlertMe(self, didChangeZoneStatus: isInside)
        }
    }

    @objc private func onDidEnterZone(_ notification: NSNotification) {
        guard let zone = zoneFromUserInfo(notification.userInfo) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.placeAlertMe(self, didEnter: zone)
        }
    }

    @objc private func onDidExitZone(_ notification: NSNotification) {
        guard let zone = zoneFromUserInfo(notification.userInfo) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.placeAlertMe(self, didExit: zone)
        }
    }

    private func zoneFromUserInfo(_ userInfo: [AnyHashable: Any]?) -> GeoZone? {
        guard let userInfo = userInfo,
              let id = userInfo["id"] as? String,
              let latitude = userInfo["latitude"] as? Double,
              let longitude = userInfo["longitude"] as? Double,
              let radius = userInfo["radiusMeters"] as? Double else { return nil }
        return GeoZone(
            id: id,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radius,
            notifyOnEntry: userInfo["notifyOnEntry"] as? Bool ?? true,
            notifyOnExit: userInfo["notifyOnExit"] as? Bool ?? true
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Delegate

public protocol PlaceAlertMeDelegate: AnyObject {
    /// Called frequently with the latest location and distance to the
    /// nearest zone. Use for live "you are X away" UIs.
    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateGeofenceStatus status: GeofenceStatus)

    /// Global "you crossed into / out of *any* zone" event. Coarse —
    /// doesn't tell you which zone. New code should prefer the per-zone
    /// callbacks below.
    func placeAlertMe(_ tracker: PlaceAlertMe, didChangeZoneStatus isInside: Bool)

    /// Per-zone entry event. Fires exactly once per logical transition
    /// regardless of which engine detected it. Also fires when the user
    /// is already inside a zone at the moment it's registered.
    func placeAlertMe(_ tracker: PlaceAlertMe, didEnter zone: GeoZone)

    /// Per-zone exit event. Fires exactly once per logical transition.
    func placeAlertMe(_ tracker: PlaceAlertMe, didExit zone: GeoZone)
}

// Default implementations so existing delegates compile without changes.
public extension PlaceAlertMeDelegate {
    func placeAlertMe(_ tracker: PlaceAlertMe, didEnter zone: GeoZone) {}
    func placeAlertMe(_ tracker: PlaceAlertMe, didExit zone: GeoZone) {}
    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateGeofenceStatus status: GeofenceStatus) {}
    func placeAlertMe(_ tracker: PlaceAlertMe, didChangeZoneStatus isInside: Bool) {}
}

// MARK: - Status struct

public struct GeofenceStatus {
    public let isInside: Bool
    public let latitude: Double
    public let longitude: Double
    public let distance: Double
    public let nextIntervalMs: Int64

    public var nextIntervalSeconds: TimeInterval {
        TimeInterval(nextIntervalMs) / 1000.0
    }
}
#endif
