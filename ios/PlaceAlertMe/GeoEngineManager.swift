import Foundation

#if os(iOS)
import CoreLocation

internal class GeoEngineManager {
    static let shared = GeoEngineManager()

    private init() {
        ios_geo_engine_initialize()
    }

    func addZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        ios_geo_engine_add_zone(latitude, longitude, radiusMeters)
    }

    func clearZones() {
        ios_geo_engine_clear_zones()
    }

    func getZoneCount() -> Int {
        return Int(ios_geo_engine_get_zone_count())
    }

    func processLocation(latitude: Double, longitude: Double, speedMps: Double) -> GeoEngineResponse {
        let result = ios_geo_engine_process_location(latitude, longitude, speedMps)
        return GeoEngineResponse(
            isInsideZone: result.isInsideZone,
            nextIntervalMs: Int64(result.nextIntervalMs),
            distanceMeters: result.distanceMeters
        )
    }
}

struct GeoEngineResponse {
    let isInsideZone: Bool
    let nextIntervalMs: Int64
    let distanceMeters: Double

    var nextIntervalSeconds: TimeInterval {
        return TimeInterval(nextIntervalMs) / 1000.0
    }
}
#endif
