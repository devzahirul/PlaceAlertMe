import Foundation

/// A single geofence zone with a stable identifier.
///
/// `id` must be unique within a `PlaceAlertMe` session. The system
/// geofence monitor uses this id as the `CLRegion.identifier`, so the
/// id round-trips through iOS even when the app is terminated and woken
/// for a region event.
public struct GeoZone: Identifiable, Hashable, Codable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let radiusMeters: Double

    /// If true, the host receives `didEnter` callbacks for this zone.
    public var notifyOnEntry: Bool

    /// If true, the host receives `didExit` callbacks for this zone.
    public var notifyOnExit: Bool

    public init(
        id: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = true
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.notifyOnEntry = notifyOnEntry
        self.notifyOnExit = notifyOnExit
    }
}
