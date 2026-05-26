import Foundation

public class PlaceAlertMe {
    public static let shared = PlaceAlertMe()

    private let coordinator = TrackingCoordinator.shared
    public weak var delegate: PlaceAlertMeDelegate?

    private init() {
        setupNotificationListeners()
    }

    // MARK: - Live tracking

    public func startTracking() {
        coordinator.startTracking()
    }

    public func stopTracking() {
        coordinator.stopTracking()
    }

    public func addGeofenceZone(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) {
        coordinator.addGeofenceZone(id: id, name: name,
                                     latitude: latitude, longitude: longitude,
                                     radiusMeters: radiusMeters)
    }

    @available(*, deprecated, message: "Use addGeofenceZone(id:name:latitude:longitude:radiusMeters:) instead")
    public func addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        coordinator.addGeofenceZone(id: UUID().uuidString, name: "Zone",
                                     latitude: latitude, longitude: longitude,
                                     radiusMeters: radiusMeters)
    }

    public func clearGeofenceZones() {
        coordinator.clearGeofenceZones()
    }

    // MARK: - Internal: notification → delegate bridge

    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onZoneEnter(_:)),
            name: NSNotification.Name("ZoneEnter"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onZoneExit(_:)),
            name: NSNotification.Name("ZoneExit"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onGeofenceStatusChanged(_:)),
            name: NSNotification.Name("GeofenceStatusChanged"),
            object: nil
        )
    }

    @objc private func onZoneEnter(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        let zoneId = userInfo["zoneId"] as? String ?? ""
        let zoneName = userInfo["zoneName"] as? String ?? ""
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.placeAlertMe(self, didEnterZone: zoneId, name: zoneName)
        }
    }

    @objc private func onZoneExit(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        let zoneId = userInfo["zoneId"] as? String ?? ""
        let zoneName = userInfo["zoneName"] as? String ?? ""
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.placeAlertMe(self, didExitZone: zoneId, name: zoneName)
        }
    }

    @objc private func onGeofenceStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isInside = userInfo["isInside"] as? Bool ?? false
            let distance = userInfo["distance"] as? Double ?? 0.0
            let nextInterval = userInfo["nextInterval"] as? Int64 ?? 10000
            let latitude = userInfo["latitude"] as? Double ?? 0.0
            let longitude = userInfo["longitude"] as? Double ?? 0.0

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
    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateGeofenceStatus status: GeofenceStatus)
    func placeAlertMe(_ tracker: PlaceAlertMe, didEnterZone id: String, name: String)
    func placeAlertMe(_ tracker: PlaceAlertMe, didExitZone id: String, name: String)
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
