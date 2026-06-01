import Foundation

#if os(iOS)
import UserNotifications

internal class PlaceNotificationManager {
    static let shared = PlaceNotificationManager()
    private init() {}

    /// When false, the SDK suppresses its own enter/exit notifications so the
    /// host app can present its own (avoids duplicate banners).
    var isEnabled = true

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    func notifyApproaching(zoneId: String, zoneName: String) {
        guard !zoneName.isEmpty else { return }
        send(id: "\(zoneId)-approaching",
             title: "Approaching \(zoneName)",
             body: "You are approaching \(zoneName)")
    }

    func notifyEnter(zoneId: String, zoneName: String) {
        guard !zoneName.isEmpty else { return }
        send(id: "\(zoneId)-enter",
             title: "Arrived at \(zoneName)",
             body: "You have arrived at \(zoneName)")
    }

    func notifyExit(zoneId: String, zoneName: String) {
        guard !zoneName.isEmpty else { return }
        send(id: "\(zoneId)-exit",
             title: "Left \(zoneName)",
             body: "You have left \(zoneName)")
    }

    private func send(id: String, title: String, body: String) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[PlaceAlertMe] notification error: \(error.localizedDescription)")
            }
        }
    }
}
#endif
