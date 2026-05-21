import Foundation
import PlaceAlertMe
import Testing
@testable import PlaceAlertCo

@MainActor
struct PlaceAlertCoTests {

    @Test func transitionHistoryStoreRecordsFilteredRouteAndAlertEvent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaceAlertCoTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = TransitionHistoryStore(directoryURL: directory)
        let timestamp = Date(timeIntervalSince1970: 1_779_286_400)

        #expect(store.recordLocation(latitude: 23.7800, longitude: 90.4100, timestamp: timestamp))
        #expect(!store.recordLocation(
            latitude: 23.78001,
            longitude: 90.41001,
            timestamp: timestamp.addingTimeInterval(10)
        ))

        let alert = Alert(
            task: "Buy groceries",
            place: "Market",
            address: "Dhaka",
            latitude: 23.7800,
            longitude: 90.4100,
            radiusMeters: 250,
            trigger: .arriving
        )
        #expect(store.recordAlert(alert: alert, entering: true, timestamp: timestamp))

        store.refresh()

        let dayKey = TransitionHistoryStore.dayKey(for: timestamp)
        let day = try #require(store.loadDay(dayKey: dayKey))
        #expect(day.points.count == 1)
        #expect(day.alertEvents.count == 1)
        #expect(day.summary.alertEventCount == 1)
        #expect(store.summaries.first?.dayKey == dayKey)
    }

}
