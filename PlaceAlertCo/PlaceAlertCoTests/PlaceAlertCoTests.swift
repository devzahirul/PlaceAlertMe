import Foundation
import CoreLocation
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

    @Test func roadRouteResolverStitchesRoutedSegments() async throws {
        let start = coordinate(23.7800, 90.4100)
        let middle = coordinate(23.7810, 90.4110)
        let end = coordinate(23.7820, 90.4120)
        let firstRoadBend = coordinate(23.7804, 90.4103)
        let secondRoadBend = coordinate(23.7815, 90.4118)
        let router = FakeRoadRouteRouter(responses: [
            .success([start, firstRoadBend, middle]),
            .success([middle, secondRoadBend, end]),
        ])
        let resolver = RoadRouteResolver(router: router)

        let result = await resolver.roadCoordinates(
            dayKey: "2026-05-22",
            rawCoordinates: [start, middle, end]
        )

        #expect(router.requests.count == 2)
        expectCoordinates(result, [start, firstRoadBend, middle, secondRoadBend, end])
    }

    @Test func roadRouteResolverFallsBackPerFailedSegment() async throws {
        let start = coordinate(23.7800, 90.4100)
        let middle = coordinate(23.7810, 90.4110)
        let end = coordinate(23.7820, 90.4120)
        let roadBend = coordinate(23.7815, 90.4118)
        let router = FakeRoadRouteRouter(responses: [
            .failure(FakeRouteError.failed),
            .success([middle, roadBend, end]),
        ])
        let resolver = RoadRouteResolver(router: router)

        let result = await resolver.roadCoordinates(
            dayKey: "2026-05-22",
            rawCoordinates: [start, middle, end]
        )

        #expect(router.requests.count == 2)
        expectCoordinates(result, [start, middle, roadBend, end])
    }

    @Test func roadRouteResolverCachesResolvedRoute() async throws {
        let start = coordinate(23.7800, 90.4100)
        let end = coordinate(23.7820, 90.4120)
        let roadBend = coordinate(23.7810, 90.4115)
        let router = FakeRoadRouteRouter(responses: [
            .success([start, roadBend, end]),
        ])
        let resolver = RoadRouteResolver(router: router)

        let first = await resolver.roadCoordinates(
            dayKey: "2026-05-22",
            rawCoordinates: [start, end]
        )
        let second = await resolver.roadCoordinates(
            dayKey: "2026-05-22",
            rawCoordinates: [start, end]
        )

        #expect(router.requests.count == 1)
        expectCoordinates(first, [start, roadBend, end])
        expectCoordinates(second, [start, roadBend, end])
    }

    @Test func transitionHistoryRecordsActivityBoundariesForRoute() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaceAlertCoActivityTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = TransitionHistoryStore(directoryURL: directory)
        let start = Date(timeIntervalSince1970: 1_779_286_400)
        #expect(store.recordLocation(latitude: 23.7800, longitude: 90.4100, timestamp: start))
        #expect(store.recordActivity(
            activityType: PlaceAlertActivityType.walking.rawValue,
            confidence: PlaceAlertActivityConfidence.high.rawValue,
            timestamp: start.addingTimeInterval(5)
        ))
        #expect(!store.recordActivity(
            activityType: PlaceAlertActivityType.walking.rawValue,
            confidence: PlaceAlertActivityConfidence.medium.rawValue,
            timestamp: start.addingTimeInterval(10)
        ))
        #expect(store.recordLocation(
            latitude: 23.7820,
            longitude: 90.4120,
            timestamp: start.addingTimeInterval(70)
        ))
        #expect(store.recordActivity(
            activityType: PlaceAlertActivityType.automotive.rawValue,
            confidence: PlaceAlertActivityConfidence.medium.rawValue,
            timestamp: start.addingTimeInterval(75)
        ))
        #expect(store.recordLocation(
            latitude: 23.7840,
            longitude: 90.4140,
            timestamp: start.addingTimeInterval(140)
        ))

        let day = try #require(store.loadDay(dayKey: TransitionHistoryStore.dayKey(for: start)))
        #expect(day.activityEvents.map(\.activityType) == ["walking", "automotive"])

        let boundaries = TransitionActivityBoundaryBuilder.boundaries(for: day)
        #expect(boundaries.count == 4)
        #expect(boundaries.map(\.title) == [
            "Walking start",
            "Walking end",
            "Automotive start",
            "Automotive end",
        ])
        #expect(boundaries[0].role == .start)
        #expect(boundaries[1].role == .end)
    }

    @Test func transitionRoadTimelineCollapsesConsecutiveRoadNames() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaceAlertCoRoadTimelineTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = TransitionHistoryStore(directoryURL: directory)
        let start = Date(timeIntervalSince1970: 1_779_286_400)
        #expect(store.recordLocation(latitude: 23.7800, longitude: 90.4100, timestamp: start))
        #expect(store.recordLocation(latitude: 23.7810, longitude: 90.4110, timestamp: start.addingTimeInterval(70)))
        #expect(store.recordLocation(latitude: 23.7900, longitude: 90.4200, timestamp: start.addingTimeInterval(140)))
        #expect(store.recordLocation(latitude: 23.7910, longitude: 90.4210, timestamp: start.addingTimeInterval(210)))

        let day = try #require(store.loadDay(dayKey: TransitionHistoryStore.dayKey(for: start)))
        let resolver = TransitionRoadTimelineResolver(
            roadNameResolver: FakeRoadNameResolver(names: [
                "Road 11",
                "Road 11",
                "Satmasjid Road",
                "Satmasjid Road",
            ]),
            maxSampleCount: 8
        )

        let items = await resolver.timeline(for: day)
        #expect(items.map(\.roadName) == ["Road 11", "Satmasjid Road"])
        #expect(items[0].startTimestampMs == Int64(start.timeIntervalSince1970 * 1000))
        #expect(items[1].endTimestampMs == Int64(start.addingTimeInterval(210).timeIntervalSince1970 * 1000))
    }

}

private final class FakeRoadRouteRouter: RoadRouteRouting {
    private var responses: [Result<[CLLocationCoordinate2D], Error>]
    private(set) var requests: [(source: CLLocationCoordinate2D, destination: CLLocationCoordinate2D)] = []

    init(responses: [Result<[CLLocationCoordinate2D], Error>]) {
        self.responses = responses
    }

    func routeCoordinates(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> [CLLocationCoordinate2D] {
        requests.append((source, destination))
        guard !responses.isEmpty else {
            return [source, destination]
        }
        return try responses.removeFirst().get()
    }
}

private enum FakeRouteError: Error {
    case failed
}

private final class FakeRoadNameResolver: TransitionRoadNameResolving {
    private var names: [String?]

    init(names: [String?]) {
        self.names = names
    }

    func roadName(for coordinate: CLLocationCoordinate2D) async -> String? {
        guard !names.isEmpty else { return nil }
        return names.removeFirst()
    }
}

private func coordinate(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
}

private func expectCoordinates(
    _ actual: [CLLocationCoordinate2D],
    _ expected: [CLLocationCoordinate2D]
) {
    #expect(actual.count == expected.count)
    for index in 0..<min(actual.count, expected.count) {
        #expect(abs(actual[index].latitude - expected[index].latitude) < 0.000001)
        #expect(abs(actual[index].longitude - expected[index].longitude) < 0.000001)
    }
}
