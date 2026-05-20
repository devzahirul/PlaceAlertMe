import UIKit
import CoreLocation

class SampleViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var addZoneButton: UIButton!

    private var isTracking = false
    private let coordinator = TrackingCoordinator.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNotifications()
    }

    private func setupUI() {
        statusLabel.text = "Ready"
        statusLabel.numberOfLines = 0

        startButton.addTarget(self, action: #selector(onStartTracking), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(onStopTracking), for: .touchUpInside)
        addZoneButton.addTarget(self, action: #selector(onAddZone), for: .touchUpInside)

        updateUI()
    }

    private func setupNotifications() {
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

    @objc private func onStartTracking() {
        coordinator.startTracking()
        isTracking = true
        statusLabel.text = "Tracking started..."
        updateUI()
    }

    @objc private func onStopTracking() {
        coordinator.stopTracking()
        isTracking = false
        statusLabel.text = "Tracking stopped"
        updateUI()
    }

    @objc private func onAddZone() {
        // Example: Add a geofence zone around San Francisco
        coordinator.addGeofenceZone(
            latitude: 37.7749,
            longitude: -122.4194,
            radiusMeters: 5000.0  // 5 km radius
        )

        statusLabel.text = "Added zone: San Francisco (5km radius)"
    }

    @objc private func onGeofenceStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }

        DispatchQueue.main.async {
            let isInside = userInfo["isInside"] as? Bool ?? false
            let distance = userInfo["distance"] as? Double ?? 0.0
            let nextInterval = userInfo["nextInterval"] as? Int64 ?? 10000
            let latitude = userInfo["latitude"] as? Double ?? 0.0
            let longitude = userInfo["longitude"] as? Double ?? 0.0

            let status = """
            Status: \(isInside ? "INSIDE ZONE" : "OUTSIDE ZONE")
            Location: \(latitude), \(longitude)
            Distance: \(String(format: "%.2f", distance)) m
            Next Update: \(nextInterval)ms
            """

            self.statusLabel.text = status
        }
    }

    @objc private func onGeofenceZoneStatusChanged(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }

        DispatchQueue.main.async {
            let isInside = userInfo["isInside"] as? Bool ?? false

            if isInside {
                self.showAlert(title: "Zone Entered", message: "You have entered the geofence zone")
            } else {
                self.showAlert(title: "Zone Exited", message: "You have exited the geofence zone")
            }
        }
    }

    private func updateUI() {
        startButton.isEnabled = !isTracking
        stopButton.isEnabled = isTracking
        addZoneButton.isEnabled = isTracking
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
