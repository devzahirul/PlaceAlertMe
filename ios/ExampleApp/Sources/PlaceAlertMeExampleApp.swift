import SwiftUI
import PlaceAlertMe

@main
struct PlaceAlertMeExampleApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.requestLocationPermissions()
                }
        }
    }
}

@MainActor
class AppViewModel: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var zones: [GeofenceZone] = []
    @Published var selectedTab: Tab = .home
    @Published var showAddZoneDialog = false
    @Published var showMapPicker = false

    private let tracker = PlaceAlertMe.shared
    private var locationManager: CLLocationManager?

    override init() {
        super.init()
        setupLocationManager()
        loadZones()
    }

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
    }

    func requestLocationPermissions() {
        locationManager?.requestWhenInUseAuthorization()
    }

    func startTracking() {
        tracker.startTracking { result in
            DispatchQueue.main.async {
                self.isTracking = result
            }
        }
    }

    func stopTracking() {
        tracker.stopTracking()
        self.isTracking = false
    }

    func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    func addZone(latitude: Double, longitude: Double, radius: Double) {
        let zone = GeofenceZone(
            id: UUID().uuidString,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            name: "Zone \(zones.count + 1)"
        )
        zones.append(zone)
        tracker.addZone(latitude: latitude, longitude: longitude, radius: radius)
        saveZones()
    }

    func removeZone(id: String) {
        zones.removeAll { $0.id == id }
        saveZones()
    }

    private func loadZones() {
        if let data = UserDefaults.standard.data(forKey: "zones"),
           let decoded = try? JSONDecoder().decode([GeofenceZone].self, from: data) {
            zones = decoded
        }
    }

    private func saveZones() {
        if let encoded = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(encoded, forKey: "zones")
        }
    }

    enum Tab {
        case home
        case map
        case settings
    }
}

struct GeofenceZone: Identifiable, Codable {
    let id: String
    let latitude: Double
    let longitude: Double
    let radius: Double
    let name: String
}
