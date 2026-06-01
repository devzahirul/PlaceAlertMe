import Foundation

public struct PlaceRecord: Codable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let radiusMeters: Double

    public init(id: String, name: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }
}

internal class PlaceStore {
    static let shared = PlaceStore()
    private let key = "PlaceAlertMe.zones"

    private init() {}

    func save(_ zones: [PlaceRecord]) {
        if let data = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> [PlaceRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let zones = try? JSONDecoder().decode([PlaceRecord].self, from: data) else {
            return []
        }
        return zones
    }

    func add(_ zone: PlaceRecord) {
        var zones = load()
        zones.removeAll { $0.id == zone.id }
        zones.append(zone)
        save(zones)
    }

    func remove(id: String) {
        var zones = load()
        zones.removeAll { $0.id == id }
        save(zones)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
