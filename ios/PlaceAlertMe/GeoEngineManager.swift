import Foundation

#if os(iOS)
import CoreLocation
import GeoEngineWrapper

public enum TransitionType {
    case approaching
    case enter
    case exit
}

public struct ZoneTransition {
    public let zoneId: String
    public let zoneName: String
    public let type: TransitionType
    public let distanceMeters: Double
    public let latitude: Double
    public let longitude: Double
    public let speedMps: Double
    public let timestampMs: Int64
}

public struct GeoEngineResponse {
    public let isInsideAnyZone: Bool
    public let nextIntervalMs: Int64
    public let distanceToNearestMeters: Double
    public let transitions: [ZoneTransition]

    public var nextIntervalSeconds: TimeInterval {
        TimeInterval(nextIntervalMs) / 1000.0
    }
}

// Used by the system-geofence (terminated-state) path.
struct GeoEngineZoneTransition {
    let zoneId: String
    let isInside: Bool
    let zoneIndex: Int
    let distanceMeters: Double
}

struct GeoEngineNearestZoneResult {
    let zoneId: String
    let zoneIndex: Int
    let distanceMeters: Double
}

internal class GeoEngineManager {
    static let shared = GeoEngineManager()

    // Swift-side zone list for nearest-zone / movement queries.
    private struct ZoneRecord {
        let id: String
        let latitude: Double
        let longitude: Double
        let radiusMeters: Double
    }
    private var registeredZones: [ZoneRecord] = []

    private init() {
        ios_geo_engine_initialize()
    }

    // MARK: - Zone management

    func addZone(id: String, name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        ios_geo_engine_add_zone(id, name, latitude, longitude, radiusMeters)
        registeredZones.removeAll { $0.id == id }
        registeredZones.append(ZoneRecord(id: id, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters))
    }

    func addZone(_ zone: GeoZone) {
        // GeoZone has no name field — use id as name.
        addZone(id: zone.id, name: zone.id,
                latitude: zone.latitude, longitude: zone.longitude,
                radiusMeters: zone.radiusMeters)
    }

    func removeZone(id: String) {
        ios_geo_engine_remove_zone(id)
        registeredZones.removeAll { $0.id == id }
    }

    func clearZones() {
        ios_geo_engine_clear_zones()
        registeredZones.removeAll()
    }

    func getZoneCount() -> Int {
        Int(ios_geo_engine_get_zone_count())
    }

    // MARK: - Location processing (Life360 stateful engine)

    func processLocation(latitude: Double, longitude: Double,
                         speedMps: Double,
                         accuracyMeters: Double,
                         timestampMs: Int64) -> GeoEngineResponse {
        let result = ios_geo_engine_process_location(
            latitude, longitude, speedMps, accuracyMeters, timestampMs
        )

        var transitions: [ZoneTransition] = []
        let count = Int(result.transitionCount)
        withUnsafeBytes(of: result.transitions) { rawPtr in
            let stride = MemoryLayout<GeoEngineTransition>.stride
            for i in 0..<min(count, 20) {
                let tPtr = rawPtr.baseAddress!
                    .advanced(by: i * stride)
                    .bindMemory(to: GeoEngineTransition.self, capacity: 1)
                let t = tPtr.pointee
                let zoneId   = withUnsafeBytes(of: t.zoneId)   {
                    String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self))
                }
                let zoneName = withUnsafeBytes(of: t.zoneName) {
                    String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self))
                }
                let transitionType: TransitionType
                switch t.type {
                case 0:
                    transitionType = .approaching
                case 1:
                    transitionType = .enter
                default:
                    transitionType = .exit
                }
                transitions.append(ZoneTransition(
                    zoneId:         zoneId,
                    zoneName:       zoneName,
                    type:           transitionType,
                    distanceMeters: t.distanceMeters,
                    latitude:       t.latitude,
                    longitude:      t.longitude,
                    speedMps:       t.speedMps,
                    timestampMs:    Int64(t.timestampMs)
                ))
            }
        }

        return GeoEngineResponse(
            isInsideAnyZone:         result.isInsideAnyZone,
            nextIntervalMs:          Int64(result.nextIntervalMs),
            distanceToNearestMeters: result.distanceToNearestMeters,
            transitions:             transitions
        )
    }

    // MARK: - System-geofence support (terminated-state path)

    /// Called when iOS CLRegion fires while app is in terminated/background state.
    /// Trusts the OS-provided event and surfaces it without re-running dwell logic.
    func updateZoneState(zoneId: String, isInside: Bool) -> GeoEngineZoneTransition? {
        let idx = registeredZones.firstIndex(where: { $0.id == zoneId }) ?? -1
        return GeoEngineZoneTransition(zoneId: zoneId, isInside: isInside,
                                       zoneIndex: idx, distanceMeters: 0.0)
    }

    /// Returns up to `maxCount` zones nearest to the given coordinate.
    /// Used by SystemGeofenceManager to select which 20 CLRegions to register.
    func nearestZoneIds(latitude: Double, longitude: Double,
                        maxCount: Int) -> [GeoEngineNearestZoneResult] {
        let sorted = registeredZones
            .map { zone -> (dist: Double, id: String, idx: Int) in
                let dist = haversineDistance(lat1: latitude, lon1: longitude,
                                             lat2: zone.latitude, lon2: zone.longitude)
                let idx = registeredZones.firstIndex(where: { $0.id == zone.id }) ?? -1
                return (dist, zone.id, idx)
            }
            .sorted { $0.dist < $1.dist }

        return sorted.prefix(maxCount).map {
            GeoEngineNearestZoneResult(zoneId: $0.id, zoneIndex: $0.idx, distanceMeters: $0.dist)
        }
    }

    /// True when the straight-line distance between the two coordinates exceeds threshold.
    func hasMovedSignificantly(fromLatitude: Double, fromLongitude: Double,
                               toLatitude: Double, toLongitude: Double,
                               thresholdMeters: Double) -> Bool {
        haversineDistance(lat1: fromLatitude, lon1: fromLongitude,
                          lat2: toLatitude, lon2: toLongitude) >= thresholdMeters
    }

    // MARK: - Private

    private func haversineDistance(lat1: Double, lon1: Double,
                                   lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0)
              * sin(dLon / 2) * sin(dLon / 2)
        return R * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
    }
}
#endif
