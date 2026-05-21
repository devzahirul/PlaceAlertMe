import Foundation

#if os(iOS)
import CoreLocation
import GeoEngineWrapper

internal class GeoEngineManager {
    static let shared = GeoEngineManager()

    private init() {
        ios_geo_engine_initialize()
    }

    func addZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        ios_geo_engine_add_zone(latitude, longitude, radiusMeters)
    }

    func addZone(_ zone: GeoZone) {
        zone.id.withCString { zoneId in
            ios_geo_engine_add_zone_with_id(
                zoneId,
                zone.latitude,
                zone.longitude,
                zone.radiusMeters,
                zone.notifyOnEntry,
                zone.notifyOnExit
            )
        }
    }

    func clearZones() {
        ios_geo_engine_clear_zones()
    }

    func getZoneCount() -> Int {
        return Int(ios_geo_engine_get_zone_count())
    }

    func processLocation(latitude: Double, longitude: Double, speedMps: Double) -> GeoEngineResponse {
        var rawTransitions = Array(repeating: GeoEngineTransition(), count: 128)
        let result = rawTransitions.withUnsafeMutableBufferPointer { buffer in
            ios_geo_engine_process_location_with_events(
                latitude,
                longitude,
                speedMps,
                buffer.baseAddress,
                Int32(buffer.count)
            )
        }

        let transitionCount = max(0, min(Int(result.transitionCount), rawTransitions.count))
        let transitions = rawTransitions.prefix(transitionCount).compactMap { transition -> GeoEngineZoneTransition? in
            guard let zoneIdPointer = transition.zoneId else { return nil }
            return GeoEngineZoneTransition(
                zoneId: String(cString: zoneIdPointer),
                isInside: transition.isInside,
                zoneIndex: Int(transition.zoneIndex),
                distanceMeters: transition.distanceMeters
            )
        }

        return GeoEngineResponse(
            isInsideZone: result.isInsideZone,
            nextIntervalMs: Int64(result.nextIntervalMs),
            distanceMeters: result.distanceMeters,
            transitions: transitions
        )
    }

    func updateZoneState(zoneId: String, isInside: Bool) -> GeoEngineZoneTransition? {
        var rawTransition = GeoEngineTransition()
        let shouldNotify = zoneId.withCString { zoneIdPointer in
            ios_geo_engine_update_zone_state(zoneIdPointer, isInside, &rawTransition)
        }
        guard shouldNotify, let rawZoneId = rawTransition.zoneId else { return nil }
        return GeoEngineZoneTransition(
            zoneId: String(cString: rawZoneId),
            isInside: rawTransition.isInside,
            zoneIndex: Int(rawTransition.zoneIndex),
            distanceMeters: rawTransition.distanceMeters
        )
    }

    func nearestZoneIds(latitude: Double, longitude: Double, maxCount: Int) -> [GeoEngineNearestZoneResult] {
        guard maxCount > 0 else { return [] }

        var rawZones = Array(repeating: GeoEngineNearestZone(), count: maxCount)
        let count = rawZones.withUnsafeMutableBufferPointer { buffer in
            ios_geo_engine_get_nearest_zones(
                latitude,
                longitude,
                buffer.baseAddress,
                Int32(buffer.count)
            )
        }

        let safeCount = max(0, min(Int(count), rawZones.count))
        return rawZones.prefix(safeCount).compactMap { zone in
            guard let zoneIdPointer = zone.zoneId else { return nil }
            return GeoEngineNearestZoneResult(
                zoneId: String(cString: zoneIdPointer),
                zoneIndex: Int(zone.zoneIndex),
                distanceMeters: zone.distanceMeters
            )
        }
    }

    func hasMovedSignificantly(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
        thresholdMeters: Double
    ) -> Bool {
        ios_geo_engine_has_moved_significantly(
            fromLatitude,
            fromLongitude,
            toLatitude,
            toLongitude,
            thresholdMeters
        )
    }
}

struct GeoEngineResponse {
    let isInsideZone: Bool
    let nextIntervalMs: Int64
    let distanceMeters: Double
    let transitions: [GeoEngineZoneTransition]

    var nextIntervalSeconds: TimeInterval {
        return TimeInterval(nextIntervalMs) / 1000.0
    }
}

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
#endif
