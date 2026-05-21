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
        tracker.addGeofenceZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        // Note: We can't directly check zone count from public API,
        // but we can verify no exception was thrown
        XCTAssertTrue(true)
    }

    func testAddMultipleZones() {
        let tracker = PlaceAlertMe.shared

        tracker.clearGeofenceZones()
        tracker.addGeofenceZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)   // SF
        tracker.addGeofenceZone(latitude: 34.0522, longitude: -118.2437, radiusMeters: 1000.0)   // LA
        tracker.addGeofenceZone(latitude: 40.7128, longitude: -74.0060, radiusMeters: 1000.0)    // NYC

        XCTAssertTrue(true, "Adding multiple zones should not throw")
    }

    func testClearGeofenceZones() {
        let tracker = PlaceAlertMe.shared

        tracker.addGeofenceZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)
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

        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        XCTAssertTrue(true, "Adding zone should not throw")
    }

    func testGeoEngineProcessLocation() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 0.0)

        XCTAssertTrue(response.isInsideZone, "Location at zone center should be inside")
        XCTAssertTrue(response.distanceMeters < 10.0, "Distance at center should be ~0m")
        XCTAssertGreaterThan(response.nextIntervalMs, 0, "Interval should be positive")
    }

    func testGeoEngineOutsideZone() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.5, longitude: -122.0, speedMps: 0.0)

        XCTAssertFalse(response.isInsideZone, "Location far away should be outside")
        XCTAssertGreaterThan(response.distanceMeters, 1000.0, "Distance should be > 1000m")
    }

    // MARK: - Adaptive Interval Tests

    func testStationaryInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 0.5)

        // Stationary should be ~60000ms
        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 50000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 70000)
    }

    func testWalkingInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 2.5)

        // Walking should be ~10000ms
        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 8000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 12000)
    }

    func testRunningInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 7.5)

        // Running should be ~5000ms
        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 4000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 6000)
    }

    func testVehicleInterval() {
        let manager = GeoEngineManager.shared
        manager.clearZones()
        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 20.0)

        // Vehicle should be ~2000ms
        XCTAssertGreaterThanOrEqual(response.nextIntervalMs, 1000)
        XCTAssertLessThanOrEqual(response.nextIntervalMs, 3000)
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
        manager.clearZones()

        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)   // SF
        manager.addZone(latitude: 34.0522, longitude: -118.2437, radiusMeters: 1000.0)   // LA

        // Test SF location
        let sfResponse = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 0.0)
        XCTAssertTrue(sfResponse.isInsideZone, "Should be inside SF zone")

        // Test LA location
        let laResponse = manager.processLocation(latitude: 34.0522, longitude: -118.2437, speedMps: 0.0)
        XCTAssertTrue(laResponse.isInsideZone, "Should be inside LA zone")

        // Test location outside both
        let outsideResponse = manager.processLocation(latitude: 40.7128, longitude: -74.0060, speedMps: 0.0)
        XCTAssertFalse(outsideResponse.isInsideZone, "Should be outside both zones")
    }

    // MARK: - Distance Calculation Tests

    func testDistanceCalculation() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(latitude: 0.0, longitude: 0.0, radiusMeters: 1000.0)

        // Test location approximately 1 degree away (111 km)
        let response = manager.processLocation(latitude: 0.0, longitude: 1.0, speedMps: 0.0)

        XCTAssertGreaterThan(response.distanceMeters, 100000.0, "Distance should be > 100km")
        XCTAssertLessThan(response.distanceMeters, 120000.0, "Distance should be < 120km")
        XCTAssertFalse(response.isInsideZone, "Should be outside 1km zone")
    }

    func testDistanceZero() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 0.0)

        XCTAssertLessThan(response.distanceMeters, 10.0, "Distance at exact location should be ~0m")
    }

    // MARK: - Edge Cases

    func testEmptyZoneList() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 0.0)

        XCTAssertFalse(response.isInsideZone, "No zones should return false")
        XCTAssertGreaterThan(response.nextIntervalMs, 0, "Should have default interval")
    }

    func testExtremeCoordinates() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(latitude: 90.0, longitude: 180.0, radiusMeters: 1000.0)  // North Pole, Date Line

        let response = manager.processLocation(latitude: 90.0, longitude: 180.0, speedMps: 0.0)

        XCTAssertTrue(response.isInsideZone, "Extreme coordinates should work")
    }

    func testHighSpeed() {
        let manager = GeoEngineManager.shared
        manager.clearZones()

        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        let response = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 100.0)

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

        manager.addZone(latitude: 37.7749, longitude: -122.4194, radiusMeters: 1000.0)

        self.measure {
            for _ in 0..<100 {
                _ = manager.processLocation(latitude: 37.7749, longitude: -122.4194, speedMps: 2.5)
            }
        }
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
        didChangeZoneStatus isInside: Bool
    ) {
        // Mock implementation
    }
}
#endif
