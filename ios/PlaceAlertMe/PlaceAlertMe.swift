import Foundation
import CoreLocation
import CoreMotion

public class PlaceAlertMe {
    public static let shared = PlaceAlertMe()

    private let coordinator = TrackingCoordinator.shared
    public weak var delegate: PlaceAlertMeDelegate?

    private init() {
        setupNotificationListeners()
    }

    // MARK: - Public API

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

    // MARK: - Private Methods

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
                isInside: isInside,
                latitude: latitude,
                longitude: longitude,
                distance: distance,
                nextIntervalMs: nextInterval
            )
            self.delegate?.placeAlertMe(self, didUpdateGeofenceStatus: status)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Public Delegate

public protocol PlaceAlertMeDelegate: AnyObject {
    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateGeofenceStatus status: GeofenceStatus)
    func placeAlertMe(_ tracker: PlaceAlertMe, didEnterZone id: String, name: String)
    func placeAlertMe(_ tracker: PlaceAlertMe, didExitZone id: String, name: String)
}

// MARK: - Public Data Structures

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
