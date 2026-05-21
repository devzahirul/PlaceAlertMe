import Foundation

#if os(iOS)
/**
 * Main public API for PlaceAlertMe geofencing
 * Simple one-step integration for iOS apps
 */
public class PlaceAlertMe {
    /// Singleton instance
    public static let shared = PlaceAlertMe()

    private let coordinator = TrackingCoordinator.shared
    public weak var delegate: PlaceAlertMeDelegate?

    private init() {
        setupNotificationListeners()
    }

    // MARK: - Public API

    /**
     * Start location tracking and activity recognition
     * Requires location permissions to be requested first
     */
    public func startTracking() {
        coordinator.startTracking()
    }

    /**
     * Stop all tracking
     */
    public func stopTracking() {
        coordinator.stopTracking()
    }

    /**
     * Add a circular geofence zone
     * - Parameters:
     *   - latitude: Zone center latitude
     *   - longitude: Zone center longitude
     *   - radiusMeters: Zone radius in meters
     */
    public func addGeofenceZone(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) {
        coordinator.addGeofenceZone(
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters
        )
    }

    /**
     * Remove all geofence zones
     */
    public func clearGeofenceZones() {
        coordinator.clearGeofenceZones()
    }

    // MARK: - Private Methods

    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onGeofenceStatusChanged(_:)),
            name: NSNotification.Name("GeofenceStatusChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onGeofenceZoneStatusChanged(_:)),
            name: NSNotification.Name("GeofenceZoneStatusChanged"),
            object: nil
        )
    }

    @objc private func onGeofenceStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }

        DispatchQueue.main.async { [weak self] in
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

            self?.delegate?.placeAlertMe(self!, didUpdateGeofenceStatus: status)
        }
    }

    @objc private func onGeofenceZoneStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }

        DispatchQueue.main.async { [weak self] in
            let isInside = userInfo["isInside"] as? Bool ?? false
            self?.delegate?.placeAlertMe(self!, didChangeZoneStatus: isInside)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Public Delegate

/**
 * Delegate for receiving geofence status updates
 */
public protocol PlaceAlertMeDelegate: AnyObject {
    /**
     * Called when location or zone status updates
     */
    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateGeofenceStatus status: GeofenceStatus)

    /**
     * Called when zone entry/exit occurs
     */
    func placeAlertMe(_ tracker: PlaceAlertMe, didChangeZoneStatus isInside: Bool)
}

// MARK: - Public Data Structures

/**
 * Current geofence status information
 */
public struct GeofenceStatus {
    /// True if currently inside any geofence zone
    public let isInside: Bool

    /// Current latitude
    public let latitude: Double

    /// Current longitude
    public let longitude: Double

    /// Distance to nearest zone center in meters
    public let distance: Double

    /// Recommended next location update interval in milliseconds
    public let nextIntervalMs: Int64

    /// Next interval as TimeInterval for use with timers
    public var nextIntervalSeconds: TimeInterval {
        TimeInterval(nextIntervalMs) / 1000.0
    }
}
#endif
