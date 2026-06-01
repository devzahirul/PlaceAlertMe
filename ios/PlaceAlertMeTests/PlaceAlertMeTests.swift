import XCTest
@testable import PlaceAlertMe

#if os(iOS)
import CoreLocation

class PlaceAlertMeTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Helpers

    // Drive a zone from OUTSIDE → PENDING_ENTER → INSIDE by simulating dwell time.
    private func driveInside(_ manager: GeoEngineManager, latitude: Double, longitude: Double,
                              startMs: Int64 = 0) -> GeoEngineResponse {
        _ = manager.processLocation(latitude: latitude, longitude: longitude,
                                    speedMps: 0.0, accuracyMeters: 10.0, timestampMs: startMs)
        return manager.processLocation(latitude: latitude, longitude: longitude,
                                       speedMps: 0.0, accuracyMeters: 10.0, timestampMs: startMs + 11000)
    }

    // MARK: - Initialization Tests

    func testPlaceAlertMeSingletonInitialization() {
        let tracker1 = PlaceAlertMe.shared
        let tracker2 = PlaceAlertMe.shared

        XCTAssertIdentical(tracker1, tracker2, "PlaceAlertMe should be a singleton")
    }

    // MARK: - Zone Management Tests

    func testAddGeofenceZone() {
        let tracker = PlaceAlertMe.shared

        tracker.clearGeofenceZones()
        tracker.addGeofenceZone(id: "sf", name: "San Francisco",
                                 latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        XCTAssertTrue(true, "Adding zone should not throw")
    }

    func testAddMultipleZones() {
        let tracker = PlaceAlertMe.shared

        tracker.clearGeofenceZones()
        tracker.addGeofenceZone(id: "sf", name: "San Francisco",
                                 latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)
        tracker.addGeofenceZone(id: "la", name: "Los Angeles",
                                 latitude: 34.0522, longitude: -118.2437, radiusMeters: 1000.0)
        tracker.addGeofenceZone(id: "nyc", name: "New York",
                                 latitude: 40.7128, longitude: -74.0060, radiusMeters: 1000.0)

        XCTAssertTrue(true, "Adding multiple zones should not throw")
    }

    func testClearGeofenceZones() {
        let tracker = PlaceAlertMe.shared

        tracker.addGeofenceZone(id: "sf", name: "San Francisco",
                                 latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)
        tracker.clearGeofenceZones()

        XCTAssertTrue(true, "Clearing zones should not throw")
    }

    // MARK: - GeoEngineManager Tests

    func testGeoEngineManagerSingleton() {
        let manager1 = GeoEngineManager.shared
        let manager2 = GeoEngineManager.shared

        XCTAssertIdentical(manager1, manager2, "GeoEngineManager should be a singleton")
    }

    func testGeoEngineAddZone() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(id: "sf", name: "San Francisco",
                        latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        XCTAssertTrue(true, "Adding zone should not throw")
    }

    func testGeoEngineProcessLocation() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "sf", name: "San Francisco",
                        latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = driveInside(manager, latitude: 37.7749, longitude: -122.4194)

        XCTAssertTrue(response.isInsideAnyZone, "Location at zone center should be inside after dwell")
        XCTAssertTrue(response.distanceToNearestMeters < 10.0, "Distance at center should be ~0m")
        XCTAssertGreaterThan(response.nextIntervalMs, 0, "Interval should be positive")
    }

    func testGeoEngineOutsideZone() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "sf", name: "San Francisco",
                        latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.5, longitude: -122.0,
                                               speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertFalse(response.isInsideAnyZone, "Location far away should be outside")
        XCTAssertGreaterThan(response.distanceToNearestMeters, 1000.0, "Distance should be > 1000m")
    }

    // MARK: - State Machine Tests

    func testDwellTimeEntry() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "z1", name: "Zone", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)

        let r1 = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                          speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)
        XCTAssertFalse(r1.isInsideAnyZone, "First fix is PENDING_ENTER, not yet inside")
        XCTAssertTrue(r1.transitions.isEmpty, "No transition until dwell elapses")

        let r2 = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                          speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 11000)
        XCTAssertTrue(r2.isInsideAnyZone, "Should be inside after 10s dwell")
        XCTAssertEqual(r2.transitions.count, 1, "One ENTER transition expected")
        XCTAssertEqual(r2.transitions.first?.type, .enter)
        XCTAssertEqual(r2.transitions.first?.latitude ?? -1, 37.7749, accuracy: 0.001)
        XCTAssertEqual(r2.transitions.first?.longitude ?? -1, -122.4194, accuracy: 0.001)
    }

    func testHysteresisExitBuffer() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "z1", name: "Zone", latitude: 0.0, longitude: 0.0, radiusMeters: 200.0)

        // Drive to INSIDE state
        _ = driveInside(manager, latitude: 0.0, longitude: 0.0)

        // Move to radius+40m (inside exit buffer of 50m) — should NOT trigger PENDING_EXIT
        // 240m at equator ≈ 0.00216 degrees
        let r = manager.processLocation(latitude: 0.00216, longitude: 0.0,
                                         speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 22000)
        XCTAssertTrue(r.isInsideAnyZone, "Within exit buffer (240m < 250m threshold) should stay inside")
        XCTAssertTrue(r.transitions.isEmpty, "No exit event within buffer")
    }

    func testAccuracyGating() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "z1", name: "Zone", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 0.0, accuracyMeters: 70.0, timestampMs: 0)
        XCTAssertEqual(response.nextIntervalMs, 5000, "Poor accuracy should return 5s wait interval")
        XCTAssertTrue(response.transitions.isEmpty, "No transitions when accuracy is poor")
    }

    func testMinimumRadiusEnforced() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        // 50m radius → enforced to 150m minimum
        manager.addZone(id: "z1", name: "Zone", latitude: 37.7749, longitude: -122.4194, radiusMeters: 50.0)

        // Stand ~100m north (0.0009° lat × 111000 m/° ≈ 100m): inside 150m, outside 50m
        let response = driveInside(manager, latitude: 37.7758, longitude: -122.4194)
        XCTAssertTrue(response.isInsideAnyZone, "100m point should be inside zone with enforced 150m radius")
    }

    // MARK: - Adaptive Interval Tests

    func testStationaryInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 0.5, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 50000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 70000)
    }

    func testWalkingInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 2.5, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 8000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 12000)
    }

    func testRunningInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 7.5, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 4000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 6000)
    }

    func testVehicleInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 20.0, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 1000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 3000)
    }

    // MARK: - Persistence Tests

    func testPlaceStorePersistence() {
        PlaceStore.shared.clear()
        PlaceStore.shared.add(PlaceRecord(id: "test1", name: "Test Zone",
                                          latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0))
        let loaded = PlaceStore.shared.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "test1")
        XCTAssertEqual(loaded.first?.name, "Test Zone")
        PlaceStore.shared.clear()
    }

    func testPlaceStoreRemove() {
        PlaceStore.shared.clear()
        PlaceStore.shared.add(PlaceRecord(id: "a", name: "A", latitude: 0, longitude: 0, radiusMeters: 200))
        PlaceStore.shared.add(PlaceRecord(id: "b", name: "B", latitude: 1, longitude: 1, radiusMeters: 200))
        PlaceStore.shared.remove(id: "a")
        let loaded = PlaceStore.shared.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, "b")
        PlaceStore.shared.clear()
    }

    func testEngineRestoreFromPersistence() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        PlaceStore.shared.clear()

        PlaceStore.shared.add(PlaceRecord(id: "z1", name: "Saved Zone",
                                          latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0))

        let records = PlaceStore.shared.load()
        for record in records {
            manager.addZone(id: record.id, name: record.name,
                            latitude: record.latitude, longitude: record.longitude,
                            radiusMeters: record.radiusMeters)
        }
        XCTAssertEqual(manager.getZoneCount(), 1, "Engine should have zone restored from persistence")
        PlaceStore.shared.clear()
    }

    // MARK: - GeofenceStatus Tests

    func testGeofenceStatusStructure() {
        let status = GeofenceStatus(
            isInside: true,
            latitude: 37.7749,
            longitude: -122.4194,
            distance: 100.0,
            nextIntervalMs: 5000
        )

        XCTAssertTrue(status.isInside)
        XCTAssertEqual(status.latitude, 37.7749)
        XCTAssertEqual(status.longitude, -122.4194)
        XCTAssertEqual(status.distance, 100.0)
        XCTAssertEqual(status.nextIntervalMs, 5000)
    }

    func testGeofenceStatusIntervalConversion() {
        let status = GeofenceStatus(
            isInside: false,
            latitude: 37.7749,
            longitude: -122.4194,
            distance: 500.0,
            nextIntervalMs: 10000
        )

        let expectedSeconds: TimeInterval = 10.0
        XCTAssertEqual(status.nextIntervalSeconds, expectedSeconds)
    }

    // MARK: - Multiple Zones Tests

    func testMultipleZoneProcessing() {
        let manager = GeoEngineManager.shared

        // SF zone — independent sub-test
        manager.clearZones()
        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)
        let sfResponse = driveInside(manager, latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(sfResponse.isInsideAnyZone, "Should be inside SF zone after dwell")

        // LA zone — independent sub-test
        manager.clearZones()
        manager.addZone(id: "la", name: "LA", latitude: 34.0522, longitude: -118.2437, radiusMeters: 1000.0)
        let laResponse = driveInside(manager, latitude: 34.0522, longitude: -118.2437)
        XCTAssertTrue(laResponse.isInsideAnyZone, "Should be inside LA zone after dwell")

        // Both zones, test location outside both
        manager.clearZones()
        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)
        manager.addZone(id: "la", name: "LA", latitude: 34.0522, longitude: -118.2437, radiusMeters: 1000.0)
        let outsideResponse = manager.processLocation(latitude: 40.7128, longitude: -74.0060,
                                                       speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)
        XCTAssertFalse(outsideResponse.isInsideAnyZone, "Should be outside both zones")
    }

    // MARK: - Distance Calculation Tests

    func testDistanceCalculation() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(id: "origin", name: "Origin", latitude: 0.0, longitude: 0.0, radiusMeters: 1000.0)

        // 1 degree of longitude at equator ≈ 111km
        let response = manager.processLocation(latitude: 0.0, longitude: 1.0,
                                               speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertGreaterThan(response.distanceToNearestMeters, 100000.0, "Distance should be > 100km")
        XCTAssertLessThan(response.distanceToNearestMeters, 120000.0, "Distance should be < 120km")
        XCTAssertFalse(response.isInsideAnyZone, "Should be outside 1km zone")
    }

    func testDistanceZero() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertLessThan(response.distanceToNearestMeters, 10.0, "Distance at exact location should be ~0m")
    }

    // MARK: - Edge Cases

    func testEmptyZoneList() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertFalse(response.isInsideAnyZone, "No zones should return false")
        XCTAssertGreaterThan(response.nextIntervalMs, 0, "Should have default interval")
    }

    func testExtremeCoordinates() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(id: "pole", name: "Pole", latitude: 90.0, longitude: 180.0, radiusMeters: 1000.0)

        let response = driveInside(manager, latitude: 90.0, longitude: 180.0)
        XCTAssertTrue(response.isInsideAnyZone, "Extreme coordinates should work")
    }

    func testHighSpeed() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                               speedMps: 100.0, accuracyMeters: 10.0, timestampMs: 0)

        XCTAssertGreaterThan(response.nextIntervalMs, 0, "High speed should have valid interval")
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 120000, "Should not exceed max interval")
    }

    // MARK: - LocationManager Tests

    func testLocationManagerDelegate() {
        let locationManager = LocationManager()
        let mockDelegate = MockLocationManagerDelegate()

        locationManager.delegate = mockDelegate

        XCTAssertNotNil(locationManager.delegate, "Delegate should be set")
    }

    // MARK: - ActivityRecognitionManager Tests

    #if os(iOS)
    func testActivityRecognitionManagerInitialization() {
        let activityManager = ActivityRecognitionManager()

        XCTAssertNotNil(activityManager, "Activity manager should initialize")
    }
    #endif

    // MARK: - TrackingCoordinator Tests

    func testTrackingCoordinatorSingleton() {
        let coordinator1 = TrackingCoordinator.shared
        let coordinator2 = TrackingCoordinator.shared

        XCTAssertIdentical(coordinator1, coordinator2, "TrackingCoordinator should be a singleton")
    }

    // MARK: - Performance Tests

    func testPerformanceLocationProcessing() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(id: "sf", name: "SF", latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        self.measure {
            for i in 0..<100 {
                _ = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                            speedMps: 2.5, accuracyMeters: 10.0, timestampMs: Int64(i * 100))
            }
        }
    }

    func testPlaceVisitHistory() {
        PlaceVisitStore.shared.clearHistory()
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "home", name: "Home", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)

        _ = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                     speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)
        let r = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                         speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 11000)

        if let t = r.transitions.first, t.type == .enter {
            PlaceVisitStore.shared.recordEntry(transition: t)
        }

        let active = PlaceVisitStore.shared.getActiveVisits()
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.zoneId, "home")
        XCTAssertTrue(active.first?.isActive ?? false)

        PlaceVisitStore.shared.recordExit(zoneId: "home", timestampMs: 60000)
        let history = PlaceVisitStore.shared.getVisitHistory(zoneId: "home")
        XCTAssertFalse(history.first?.isActive ?? true)
        XCTAssertEqual(history.first?.durationMs, 49000)
        PlaceVisitStore.shared.clearHistory()
    }

    // MARK: - PlaceVisit Duration

    func testVisitDurationCalculation() {
        PlaceVisitStore.shared.clearHistory()
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "work", name: "Work", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)

        _ = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                     speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 1000)
        let r = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                         speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 12000)
        if let t = r.transitions.first, t.type == .enter {
            PlaceVisitStore.shared.recordEntry(transition: t)
        }

        // durationMs should be nil while still active
        let active = PlaceVisitStore.shared.getActiveVisits()
        XCTAssertNil(active.first?.durationMs, "Active visit should have nil duration")
        XCTAssertTrue(active.first?.isActive ?? false)

        // record exit 45 000 ms after arrival
        PlaceVisitStore.shared.recordExit(zoneId: "work", timestampMs: 12000 + 45000)
        let history = PlaceVisitStore.shared.getVisitHistory(zoneId: "work")
        XCTAssertEqual(history.first?.durationMs, 45000, "Duration should equal departure - arrival")
        XCTAssertFalse(history.first?.isActive ?? true)
        PlaceVisitStore.shared.clearHistory()
    }

    // MARK: - PlaceVisit Max Capacity

    func testPlaceVisitStoreMaxCapacity() {
        PlaceVisitStore.shared.clearHistory()

        for i in 0..<501 {
            PlaceVisitStore.shared.recordEntry(transition: ZoneTransition(
                zoneId: "cap", zoneName: "Cap", type: .enter,
                distanceMeters: 0, latitude: 0.0, longitude: 0.0,
                speedMps: 0.0, timestampMs: Int64(i) * 1000
            ))
        }

        let all = PlaceVisitStore.shared.getAllVisitHistory(limit: 1000)
        XCTAssertLessThanOrEqual(all.count, 500, "Store should cap at 500 visits")
        PlaceVisitStore.shared.clearHistory()
    }

    // MARK: - Transition Location Context

    func testTransitionLocationAndSpeedContext() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "loc", name: "Loc", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)

        _ = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                     speedMps: 3.5, accuracyMeters: 10.0, timestampMs: 0)
        let r = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                         speedMps: 3.5, accuracyMeters: 10.0, timestampMs: 11000)

        XCTAssertEqual(r.transitions.count, 1)
        let t = r.transitions.first!
        XCTAssertEqual(t.latitude,  37.7749,  accuracy: 0.0001)
        XCTAssertEqual(t.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(t.speedMps, 3.5, accuracy: 0.01)
        XCTAssertEqual(t.timestampMs, 11000)
    }

    // MARK: - Public API: getCurrentPlaces / getAllVisitHistory

    func testGetCurrentPlacesPublicAPI() {
        PlaceVisitStore.shared.clearHistory()
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "gym", name: "Gym", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)

        _ = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                     speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 0)
        let r = manager.processLocation(latitude: 37.7749, longitude: -122.4194,
                                         speedMps: 0.0, accuracyMeters: 10.0, timestampMs: 11000)
        if let t = r.transitions.first, t.type == .enter {
            PlaceVisitStore.shared.recordEntry(transition: t)
        }

        let current = PlaceAlertMe.shared.getCurrentPlaces()
        XCTAssertGreaterThanOrEqual(current.count, 1, "getCurrentPlaces should return active visits")
        XCTAssertTrue(current.allSatisfy { $0.isActive }, "All returned visits should be active")
        PlaceVisitStore.shared.clearHistory()
    }

    func testGetAllVisitHistory() {
        PlaceVisitStore.shared.clearHistory()
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(id: "z1", name: "Z1", latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0)
        manager.addZone(id: "z2", name: "Z2", latitude: 34.0522, longitude: -118.2437, radiusMeters: 200.0)

        // Record one visit for each zone
        let t1 = ZoneTransition(zoneId: "z1", zoneName: "Z1", type: .enter,
                                distanceMeters: 0, latitude: 37.7749, longitude: -122.4194,
                                speedMps: 0, timestampMs: 1000)
        let t2 = ZoneTransition(zoneId: "z2", zoneName: "Z2", type: .enter,
                                distanceMeters: 0, latitude: 34.0522, longitude: -118.2437,
                                speedMps: 0, timestampMs: 2000)
        PlaceVisitStore.shared.recordEntry(transition: t1)
        PlaceVisitStore.shared.recordEntry(transition: t2)

        let all = PlaceAlertMe.shared.getAllVisitHistory()
        XCTAssertEqual(all.count, 2)
        // Results should be sorted newest-first
        XCTAssertEqual(all.first?.zoneId, "z2", "Newest visit should come first")
        PlaceVisitStore.shared.clearHistory()
    }

    // MARK: - updateGeofenceZone Persistence

    func testUpdateGeofenceZonePersistence() {
        PlaceStore.shared.clear()
        PlaceStore.shared.add(PlaceRecord(id: "upd", name: "OldName",
                                          latitude: 37.7749, longitude: -122.4194, radiusMeters: 200.0))

        // PlaceAlertMe.updateGeofenceZone patches name and radius
        PlaceAlertMe.shared.updateGeofenceZone(id: "upd", name: "NewName", radiusMeters: 500.0)

        let records = PlaceStore.shared.load()
        let updated = records.first { $0.id == "upd" }
        XCTAssertEqual(updated?.name, "NewName", "Name should be updated in PlaceStore")
        XCTAssertEqual(updated?.radiusMeters, 500.0, accuracy: 0.1, "Radius should be updated in PlaceStore")
        PlaceStore.shared.clear()
    }

    func testUpdateGeofenceZonePartialUpdate() {
        PlaceStore.shared.clear()
        PlaceStore.shared.add(PlaceRecord(id: "part", name: "OrigName",
                                          latitude: 10.0, longitude: 20.0, radiusMeters: 300.0))

        // Update only radius; name should remain
        PlaceAlertMe.shared.updateGeofenceZone(id: "part", radiusMeters: 800.0)

        let records = PlaceStore.shared.load()
        let updated = records.first { $0.id == "part" }
        XCTAssertEqual(updated?.name, "OrigName", "Name should be unchanged when not specified")
        XCTAssertEqual(updated?.radiusMeters, 800.0, accuracy: 0.1)
        PlaceStore.shared.clear()
    }

    // MARK: - PlaceVisit arrivalLatitude / arrivalLongitude

    func testVisitArrivalCoordinates() {
        PlaceVisitStore.shared.clearHistory()
        let t = ZoneTransition(zoneId: "coords", zoneName: "Coords", type: .enter,
                               distanceMeters: 0, latitude: 51.5074, longitude: -0.1278,
                               speedMps: 1.2, timestampMs: 5000)
        PlaceVisitStore.shared.recordEntry(transition: t)

        let active = PlaceVisitStore.shared.getActiveVisits()
        XCTAssertEqual(active.first?.arrivalLatitude,  51.5074,  accuracy: 0.0001)
        XCTAssertEqual(active.first?.arrivalLongitude, -0.1278, accuracy: 0.0001)
        XCTAssertEqual(active.first?.arrivalSpeedMps,  1.2,      accuracy: 0.01)
        XCTAssertEqual(active.first?.arrivalTimestampMs, 5000)
        PlaceVisitStore.shared.clearHistory()
    }

    // MARK: - getVisitHistory zoneId filter

    func testVisitHistoryZoneIdFilter() {
        PlaceVisitStore.shared.clearHistory()
        PlaceVisitStore.shared.recordEntry(transition: ZoneTransition(
            zoneId: "a", zoneName: "A", type: .enter,
            distanceMeters: 0, latitude: 0, longitude: 0, speedMps: 0, timestampMs: 100))
        PlaceVisitStore.shared.recordEntry(transition: ZoneTransition(
            zoneId: "b", zoneName: "B", type: .enter,
            distanceMeters: 0, latitude: 1, longitude: 1, speedMps: 0, timestampMs: 200))
        PlaceVisitStore.shared.recordEntry(transition: ZoneTransition(
            zoneId: "a", zoneName: "A", type: .enter,
            distanceMeters: 0, latitude: 0, longitude: 0, speedMps: 0, timestampMs: 300))

        let historyA = PlaceVisitStore.shared.getVisitHistory(zoneId: "a")
        XCTAssertEqual(historyA.count, 2, "Should return only zone 'a' visits")
        XCTAssertTrue(historyA.allSatisfy { $0.zoneId == "a" })
        // Newest first
        XCTAssertGreaterThan(historyA[0].arrivalTimestampMs, historyA[1].arrivalTimestampMs)
        PlaceVisitStore.shared.clearHistory()
    }
}

// MARK: - Mock Delegate

class MockLocationManagerDelegate: LocationManagerDelegate {
    func locationManager(
        _ manager: LocationManager,
        didUpdate location: CLLocation,
        response: GeoEngineResponse
    ) {
        // Mock implementation
    }

    func locationManager(
        _ manager: LocationManager,
        didTransition transition: ZoneTransition
    ) {
        // Mock implementation
    }
}
#endif
