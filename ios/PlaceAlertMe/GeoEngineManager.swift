import Foundation
import CoreLocation
import GeoEngineWrapper

public enum TransitionType {
    case enter
    case exit
}

public struct ZoneTransition {
    public let zoneId: String
    public let zoneName: String
    public let type: TransitionType
    public let distanceMeters: Double
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

internal class GeoEngineManager {
    static let shared = GeoEngineManager()

    private init() {
        ios_geo_engine_initialize()
    }

    func addZone(id: String, name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        ios_geo_engine_add_zone(id, name, latitude, longitude, radiusMeters)
    }

    func removeZone(id: String) {
        ios_geo_engine_remove_zone(id)
    }

    func clearZones() {
        ios_geo_engine_clear_zones()
    }

    func getZoneCount() -> Int {
        Int(ios_geo_engine_get_zone_count())
    }

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
                transitions.append(ZoneTransition(
                    zoneId:         zoneId,
                    zoneName:       zoneName,
                    type:           t.type == 0 ? .enter : .exit,
                    distanceMeters: t.distanceMeters,
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
}
