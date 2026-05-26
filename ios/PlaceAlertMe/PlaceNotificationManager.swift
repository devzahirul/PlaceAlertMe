import Foundation

#if os(iOS)
import UserNotifications

internal class PlaceNotificationManager {
    static let shared = PlaceNotificationManager()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
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
