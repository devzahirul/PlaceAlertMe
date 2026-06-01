import Foundation

public struct PlaceVisit: Codable, Identifiable {
    public let id: String               // UUID
    public let zoneId: String
    public let zoneName: String
    public let arrivalTimestampMs: Int64
    public var departureTimestampMs: Int64?   // nil = still inside
    public let arrivalLatitude: Double
    public let arrivalLongitude: Double
    public let arrivalSpeedMps: Double
    public let arrivalActivityType: String   // "walking", "auto", "bus", "stationary", etc.

    public var isActive: Bool { departureTimestampMs == nil }

    public var durationMs: Int64? {
        guard let dep = departureTimestampMs else { return nil }
        return dep - arrivalTimestampMs
    }

    public init(zoneId: String, zoneName: String,
                arrivalTimestampMs: Int64,
                arrivalLatitude: Double, arrivalLongitude: Double,
                arrivalSpeedMps: Double,
                arrivalActivityType: String = "unknown") {
        self.id = UUID().uuidString
        self.zoneId = zoneId
        self.zoneName = zoneName
        self.arrivalTimestampMs = arrivalTimestampMs
        self.departureTimestampMs = nil
        self.arrivalLatitude = arrivalLatitude
        self.arrivalLongitude = arrivalLongitude
        self.arrivalSpeedMps = arrivalSpeedMps
        self.arrivalActivityType = arrivalActivityType
    }
}

internal class PlaceVisitStore {
    static let shared = PlaceVisitStore()
    private let key = "PlaceAlertMe.visitHistory"
    private let maxStoredVisits = 500

    private init() {}

    func recordEntry(transition: ZoneTransition, activityType: String = "unknown") {
        var visits = loadAll()
        let visit = PlaceVisit(
            zoneId: transition.zoneId,
            zoneName: transition.zoneName,
            arrivalTimestampMs: transition.timestampMs,
            arrivalLatitude: transition.latitude,
            arrivalLongitude: transition.longitude,
            arrivalSpeedMps: transition.speedMps,
            arrivalActivityType: activityType
        )
        visits.append(visit)
        save(visits)
    }

    func recordExit(zoneId: String, timestampMs: Int64) {
        var visits = loadAll()
        if let idx = visits.indices.reversed().first(where: { visits[$0].zoneId == zoneId && visits[$0].isActive }) {
            visits[idx].departureTimestampMs = timestampMs
        }
        save(visits)
    }

    func getActiveVisits() -> [PlaceVisit] {
        loadAll().filter { $0.isActive }
    }

    func getVisitHistory(zoneId: String, limit: Int = 50) -> [PlaceVisit] {
        Array(loadAll()
            .filter { $0.zoneId == zoneId }
            .sorted { $0.arrivalTimestampMs > $1.arrivalTimestampMs }
            .prefix(limit))
    }

    func getAllVisitHistory(limit: Int = 100) -> [PlaceVisit] {
        Array(loadAll()
            .sorted { $0.arrivalTimestampMs > $1.arrivalTimestampMs }
            .prefix(limit))
    }

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func loadAll() -> [PlaceVisit] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let visits = try? JSONDecoder().decode([PlaceVisit].self, from: data) else {
            return []
        }
        return visits
    }

    private func save(_ visits: [PlaceVisit]) {
        let trimmed = Array(visits.suffix(maxStoredVisits))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
