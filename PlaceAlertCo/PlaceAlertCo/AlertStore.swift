import Foundation
import Combine
import CoreLocation
import UserNotifications
import PlaceAlertMe
import UIKit

// MARK: - Data Models
struct Alert: Identifiable, Codable {
    var id: UUID = UUID()
    var task: String
    var place: String
    var address: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var trigger: Trigger
    var icon: String = "mappin"
    var isActive: Bool = true
    var note: String = ""
    var lastFired: Date?

    enum Trigger: String, Codable {
        case arriving = "Arriving"
        case leaving = "Leaving"
        case both = "Both"
    }
}

// MARK: - Alert Store
class AlertStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var alerts: [Alert] = []

    // Live monitoring state
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var lastLocationUpdate: Date?
    @Published var isTracking: Bool = false

    static let shared = AlertStore()
    private let locationManager = CLLocationManager()
    private var lastZoneStatus: [UUID: Bool] = [:]

    private let notificationDelegate = ForegroundNotificationDelegate()

    override init() {
        super.init()
        loadAlerts()
        // Critical: install the foreground delegate BEFORE any notification is
        // scheduled. Without this, iOS silently suppresses banners while the
        // app is in the foreground — which is the most common reason geofence
        // entry "notifications don't appear".
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // Don't access PlaceAlertMe.shared here. Its internal CLLocationManager
        // sets allowsBackgroundLocationUpdates = true at init, which crashes if
        // UIBackgroundModes isn't recognized yet. Deferred to after permissions.
    }

    // MARK: - Setup
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Notification permission \(granted ? "GRANTED" : "DENIED")\(error.map { " (error: \($0))" } ?? "")")
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// Log current notification settings — useful for debugging "no banner shown".
    func logNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("🔔 Notification settings:")
            print("    authorizationStatus: \(settings.authorizationStatus.rawValue) (\(self.authStatusName(settings.authorizationStatus)))")
            print("    alertSetting: \(settings.alertSetting.rawValue)")
            print("    soundSetting: \(settings.soundSetting.rawValue)")
            print("    badgeSetting: \(settings.badgeSetting.rawValue)")
            print("    alertStyle: \(settings.alertStyle.rawValue)")
        }
    }

    private func authStatusName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown"
        }
    }

    private var hasSetupGeofenceDelegate = false
    private func setupGeofenceDelegate() {
        guard !hasSetupGeofenceDelegate else { return }
        PlaceAlertMe.shared.delegate = self
        // This app presents its own rich notifications (task text, haptics,
        // history). Suppress the SDK's built-in enter/exit banners to avoid
        // duplicates.
        PlaceAlertMe.shared.sendsSystemNotifications = false
        hasSetupGeofenceDelegate = true
    }

    // MARK: - UserDefaults Persistence
    private func loadAlerts() {
        if let data = UserDefaults.standard.data(forKey: "alerts") {
            if let decoded = try? JSONDecoder().decode([Alert].self, from: data) {
                self.alerts = decoded
                return
            }
        }
        self.alerts = []
    }

    private func saveAlerts() {
        if let encoded = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(encoded, forKey: "alerts")
        }
    }

    // MARK: - PlaceAlertMe Integration
    private func setupPlaceAlertMe() {
        guard canAccessPlaceAlertMe() else {
            print("❌ Location permissions not authorized for geofencing")
            return
        }

        // Hook up delegate the first time we access PlaceAlertMe
        setupGeofenceDelegate()

        let tracker = PlaceAlertMe.shared

        // New ID-based API: register each active alert as a named geofence zone.
        // Per-zone delegate callbacks (didEnterZone/didExitZone) identify the
        // alert by id (Alert.id.uuidString). Trigger filtering (arriving/leaving)
        // is enforced in the delegate handlers below — the engine itself has no
        // per-zone entry/exit flags. Radii below 150 m are bumped to 150 m by the
        // Life360-parity engine.
        tracker.clearGeofenceZones()
        let activeAlerts = alerts.filter(\.isActive)
        for alert in activeAlerts {
            tracker.addGeofenceZone(
                id: alert.id.uuidString,
                name: alert.place,
                latitude: alert.latitude,
                longitude: alert.longitude,
                radiusMeters: alert.radiusMeters
            )
        }

        print("📍 Registered \(activeAlerts.count) zone(s) with PlaceAlertMe")
        for alert in activeAlerts {
            print("📍   • id=\(alert.id.uuidString) @ (\(alert.latitude), \(alert.longitude)) " +
                  "r=\(Int(alert.radiusMeters))m trigger=\(alert.trigger.rawValue)")
        }

        // Live tracking (continuous GPS + activity recognition). Background
        // CLCircularRegion monitoring (survives app termination) is now
        // registered automatically by addGeofenceZone + startTracking, so there
        // is no separate enableBackgroundMonitoring call.
        tracker.startTracking()

        DispatchQueue.main.async { [weak self] in
            self?.isTracking = true
        }
        print("✅ PlaceAlertMe live tracking started (background monitoring automatic)")
        logNotificationStatus()
    }

    // MARK: - CRUD Operations
    func addAlert(_ alert: Alert) {
        requestNotificationPermission()
        alerts.append(alert)
        saveAlerts()
        resyncGeofences()
    }

    func updateAlert(_ alert: Alert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index] = alert
            saveAlerts()
            resyncGeofences()
        }
    }

    func deleteAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
        saveAlerts()
        resyncGeofences()
    }

    func toggleAlertActive(id: UUID) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isActive.toggle()
            saveAlerts()
            resyncGeofences()
        }
    }

    func clearAllAlerts() {
        alerts.removeAll()
        saveAlerts()
        resyncGeofences()
    }

    // MARK: - Geofence Synchronization
    private func resyncGeofences() {
        if canAccessPlaceAlertMe() {
            setupPlaceAlertMe()
        }
    }

    private func canAccessPlaceAlertMe() -> Bool {
        let authStatus = CLLocationManager.authorizationStatus()
        return authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse
    }

    func initializeGeofencingAfterPermissions() {
        if canAccessPlaceAlertMe() {
            requestNotificationPermission()
            setupPlaceAlertMe()
        }
    }

    // MARK: - Computed Properties
    var activeAlertsCount: Int {
        alerts.filter(\.isActive).count
    }

    var hasAlerts: Bool {
        !alerts.isEmpty
    }

    /// Closest active alert from `currentLocation` (nil if no location yet
    /// or no active alerts).
    var nearestActiveAlert: (alert: Alert, distanceMeters: Double)? {
        guard let coord = currentLocation else { return nil }
        let user = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let active = alerts.filter(\.isActive)
        guard !active.isEmpty else { return nil }

        var best: (Alert, Double)?
        for alert in active {
            let alertLoc = CLLocation(latitude: alert.latitude, longitude: alert.longitude)
            let dist = user.distance(from: alertLoc)
            if best == nil || dist < best!.1 {
                best = (alert, dist)
            }
        }
        return best.map { (alert: $0.0, distanceMeters: $0.1) }
    }

    /// Format meters as a human-readable distance: "1.2 km" or "350 m".
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        } else {
            return String(format: "%.2f km", meters / 1000)
        }
    }
}

// MARK: - PlaceAlertMeDelegate Implementation
extension AlertStore: PlaceAlertMeDelegate {
    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateGeofenceStatus status: GeofenceStatus) {
        print("📍 Update - Lat: \(String(format: "%.4f", status.latitude)), Lon: \(String(format: "%.4f", status.longitude)), Distance: \(Int(status.distance))m")

        // Publish the latest location so the UI can show the Nearest card.
        // Already on main thread per PlaceAlertMe's delegate contract, but
        // dispatch defensively to keep SwiftUI updates safe.
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = CLLocationCoordinate2D(
                latitude: status.latitude,
                longitude: status.longitude
            )
            self?.lastLocationUpdate = Date()
            self?.isTracking = true
            TransitionHistoryStore.shared.recordLocation(status: status)
        }
    }

    /// Global "you crossed *some* zone boundary" event. The new per-zone
    /// `didEnter`/`didExit` callbacks below are more useful — we keep this
    /// only to forward a stub log for debugging.
    func placeAlertMe(_ tracker: PlaceAlertMe, didChangeZoneStatus isInside: Bool) {
        print("🎯 (global) Zone status: \(isInside ? "INSIDE some zone" : "OUTSIDE all zones")")
    }

    func placeAlertMe(_ tracker: PlaceAlertMe, didUpdateActivity status: PlaceAlertActivityStatus) {
        DispatchQueue.main.async {
            TransitionHistoryStore.shared.recordActivity(status: status)
        }
    }

    /// Precise per-zone entry. The package tells us exactly *which* zone
    /// via the GeoZone id (which we set to Alert.id.uuidString).
    func placeAlertMe(_ tracker: PlaceAlertMe, didEnterZone id: String, name: String) {
        guard let alert = alertForZoneId(id) else {
            print("⚠️ didEnterZone \(id) but no matching alert found")
            return
        }
        guard alert.isActive else { return }
        guard alert.trigger == .arriving || alert.trigger == .both else {
            print("ℹ️ Entered \(alert.place) but trigger is .leaving — skipping")
            return
        }
        print("🟢 Entered zone: \(alert.place)")
        sendNotification(for: alert, entering: true)
    }

    func placeAlertMe(_ tracker: PlaceAlertMe, didExitZone id: String, name: String) {
        guard let alert = alertForZoneId(id) else {
            print("⚠️ didExitZone \(id) but no matching alert found")
            return
        }
        guard alert.isActive else { return }
        guard alert.trigger == .leaving || alert.trigger == .both else {
            print("ℹ️ Exited \(alert.place) but trigger is .arriving — skipping")
            return
        }
        print("🔴 Exited zone: \(alert.place)")
        sendNotification(for: alert, entering: false)
    }

    /// Look up the Alert that corresponds to a given zone id (Alert.id uuid string).
    private func alertForZoneId(_ id: String) -> Alert? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return alerts.first(where: { $0.id == uuid })
    }

    private func sendNotification(for alert: Alert, entering: Bool, recordHistory: Bool = true) {
        // Honor SettingsView preferences (defaults match the UI defaults).
        let defaults = UserDefaults.standard
        let soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        let hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true

        let content = UNMutableNotificationContent()
        if soundEnabled {
            content.sound = .default
        }
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        if entering {
            content.title = "📍 \(alert.task)"
            content.body = "You've arrived at \(alert.place)"
        } else {
            content.title = "👋 \(alert.task)"
            content.body = "You've left \(alert.place)"
        }
        // Attach the alert id so a future tap handler can deep-link.
        content.userInfo = ["alertId": alert.id.uuidString]

        // Local haptic for when the app is in foreground at the moment the
        // event fires. (Notifications themselves already vibrate on iOS if
        // the device is in vibrate mode — this is an extra in-app cue.)
        if hapticsEnabled {
            DispatchQueue.main.async {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(entering ? .success : .warning)
            }
        }

        // 1s trigger (not immediate) — gives iOS the chance to deliver as a
        // notification rather than a delegate-only event. Use a stable
        // identifier so multiple rapid entries don't pile up.
        let identifier = "alert-\(alert.id.uuidString)-\(entering ? "in" : "out")"
        let historyTimestamp = Date()
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error for \(alert.place): \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled for \(alert.place) [\(entering ? "ARRIVING" : "LEAVING")] id=\(identifier) sound=\(soundEnabled) haptics=\(hapticsEnabled)")
                if recordHistory {
                    DispatchQueue.main.async {
                        TransitionHistoryStore.shared.recordAlert(
                            alert: alert,
                            entering: entering,
                            timestamp: historyTimestamp
                        )
                    }
                }
            }
        }
    }

    /// Force-send a test notification — wired to DetailView's "Test notification" button.
    func sendTestNotification(for alert: Alert) {
        sendNotification(for: alert, entering: true, recordHistory: false)
    }
}

// MARK: - Foreground Notification Delegate
/// Required to show notification banners while the app is in the foreground.
/// Without this, iOS silently swallows the banner.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 [foreground] willPresent: \(notification.request.identifier)")
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}

// MARK: - Mock Data
extension Alert {
    static let samples: [Alert] = [
        Alert(
            task: "Buy groceries",
            place: "Bashundhara Post",
            address: "Banani, Dhaka",
            latitude: 23.8103,
            longitude: 90.4193,
            radiusMeters: 500,
            trigger: .arriving,
            icon: "cart"
        ),
        Alert(
            task: "Meet Sarah",
            place: "Caffe Aroma",
            address: "Gulshan, Dhaka",
            latitude: 23.7919,
            longitude: 90.4098,
            radiusMeters: 250,
            trigger: .both,
            icon: "cup.and.saucer"
        ),
        Alert(
            task: "Return books",
            place: "Public Library",
            address: "Motijheel, Dhaka",
            latitude: 23.7711,
            longitude: 90.4034,
            radiusMeters: 300,
            trigger: .arriving,
            icon: "book"
        ),
    ]
}
