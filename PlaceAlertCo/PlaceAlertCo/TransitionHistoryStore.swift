import Foundation
import Combine
import CoreLocation
import PlaceAlertMe

@MainActor
final class TransitionHistoryStore: ObservableObject {
    static let shared = TransitionHistoryStore()

    @Published private(set) var summaries: [NavigationHistoryDaySummary] = []

    private let manager: NavigationHistoryManager
    private let retentionDays = 90

    convenience init() {
        self.init(directoryURL: Self.defaultDirectoryURL())
    }

    init(directoryURL: URL) {
        manager = NavigationHistoryManager(directoryURL: directoryURL)
        pruneOldHistory()
        refresh()
    }

    func refresh() {
        summaries = manager.listDaySummaries()
    }

    @discardableResult
    func recordLocation(status: GeofenceStatus, timestamp: Date = Date()) -> Bool {
        recordLocation(
            latitude: status.latitude,
            longitude: status.longitude,
            speedMps: 0,
            timestamp: timestamp
        )
    }

    @discardableResult
    func recordLocation(
        latitude: Double,
        longitude: Double,
        speedMps: Double = 0,
        timestamp: Date = Date()
    ) -> Bool {
        let dayKey = Self.dayKey(for: timestamp)
        let saved = manager.appendRoutePoint(
            dayKey: dayKey,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            speedMps: speedMps
        )

        if saved {
            pruneOldHistory(now: timestamp)
            refresh()
        }
        return saved
    }

    @discardableResult
    func recordAlert(alert: Alert, entering: Bool, timestamp: Date = Date()) -> Bool {
        let dayKey = Self.dayKey(for: timestamp)
        let eventType = entering ? "Arriving" : "Leaving"
        let eventId = "\(Int64((timestamp.timeIntervalSince1970 * 1000).rounded()))-\(alert.id.uuidString)-\(eventType)"

        let saved = manager.appendAlertEvent(
            dayKey: dayKey,
            eventId: eventId,
            alertId: alert.id.uuidString,
            task: alert.task,
            place: alert.place,
            address: alert.address,
            eventType: eventType,
            timestamp: timestamp,
            latitude: alert.latitude,
            longitude: alert.longitude
        )

        if saved {
            pruneOldHistory(now: timestamp)
            refresh()
        }
        return saved
    }

    func loadDay(dayKey: String) -> NavigationHistoryDay? {
        manager.loadDay(dayKey: dayKey)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        NavigationHistoryManager.dayKey(for: date, calendar: calendar)
    }

    private func pruneOldHistory(now: Date = Date()) {
        _ = manager.prune(retentionDays: retentionDays, now: now)
    }

    private static func defaultDirectoryURL() -> URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("PlaceAlertCo", isDirectory: true)
            .appendingPathComponent("TransitionHistory", isDirectory: true)
    }
}
