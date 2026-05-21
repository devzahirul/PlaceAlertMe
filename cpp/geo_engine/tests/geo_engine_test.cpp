#include <gtest/gtest.h>
#include "geo_engine.h"
#include "history_engine.h"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

using namespace geo_engine;

class GeoEngineTest : public ::testing::Test {
protected:
    GeoEngine engine;

    void SetUp() override {
        engine.clearZones();
    }
};

class NavigationHistoryEngineTest : public ::testing::Test {
protected:
    NavigationHistoryEngine history;
    std::string directory;

    void SetUp() override {
        char templ[] = "/tmp/navigation_history_test_XXXXXX";
        char* result = mkdtemp(templ);
        ASSERT_NE(result, nullptr);
        directory = result;
    }

    void TearDown() override {
        std::remove((directory + "/2026-05-19.jsonl").c_str());
        std::remove((directory + "/2026-05-20.jsonl").c_str());
        std::remove((directory + "/2026-05-21.jsonl").c_str());
        rmdir(directory.c_str());
    }
};

// Test Zone Management
TEST_F(GeoEngineTest, AddZone) {
    EXPECT_EQ(engine.getZoneCount(), 0);

    GeofenceZone zone(37.7749, -122.4194, 1000.0);
    engine.addZone(zone);

    EXPECT_EQ(engine.getZoneCount(), 1);
}

TEST_F(GeoEngineTest, AddMultipleZones) {
    engine.addZone({37.7749, -122.4194, 1000.0});   // SF
    engine.addZone({34.0522, -118.2437, 1000.0});   // LA
    engine.addZone({40.7128, -74.0060, 1000.0});    // NYC

    EXPECT_EQ(engine.getZoneCount(), 3);
}

TEST_F(GeoEngineTest, ClearZones) {
    engine.addZone({37.7749, -122.4194, 1000.0});
    engine.addZone({34.0522, -118.2437, 1000.0});

    EXPECT_EQ(engine.getZoneCount(), 2);

    engine.clearZones();

    EXPECT_EQ(engine.getZoneCount(), 0);
}

TEST_F(GeoEngineTest, RemoveZone) {
    engine.addZone({37.7749, -122.4194, 1000.0});
    engine.addZone({34.0522, -118.2437, 1000.0});

    EXPECT_EQ(engine.getZoneCount(), 2);

    engine.removeZone(0);

    EXPECT_EQ(engine.getZoneCount(), 1);
}

// Test Zone Containment
TEST_F(GeoEngineTest, InsideZone) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.7749, -122.4194, 0.0);  // At zone center
    EngineResponse response = engine.processLocation(location);

    EXPECT_TRUE(response.isInsideZone);
    EXPECT_NEAR(response.distanceMeters, 0.0, 1.0);
}

TEST_F(GeoEngineTest, OutsideZone) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.8, -122.5, 0.0);  // Far from zone
    EngineResponse response = engine.processLocation(location);

    EXPECT_FALSE(response.isInsideZone);
    EXPECT_GT(response.distanceMeters, 1000.0);
}

TEST_F(GeoEngineTest, ZoneBoundary) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    // Approximately 1000 meters away
    UserLocation location(37.77659, -122.4194, 0.0);
    EngineResponse response = engine.processLocation(location);

    // Should be inside (within 1000m)
    EXPECT_TRUE(response.isInsideZone);
    EXPECT_LT(response.distanceMeters, 1000.0);
}

TEST_F(GeoEngineTest, MultipleZonesContainment) {
    engine.addZone({37.7749, -122.4194, 1000.0});   // SF
    engine.addZone({34.0522, -118.2437, 1000.0});   // LA

    UserLocation location(37.7749, -122.4194, 0.0);  // At SF
    EngineResponse response = engine.processLocation(location);

    EXPECT_TRUE(response.isInsideZone);
    EXPECT_NEAR(response.distanceMeters, 0.0, 1.0);
}

// Test Distance Calculation
TEST_F(GeoEngineTest, DistanceCalculation) {
    engine.addZone({0.0, 0.0, 1000.0});

    UserLocation location(0.0, 1.0, 0.0);  // 1 degree away
    EngineResponse response = engine.processLocation(location);

    // 1 degree at equator ≈ 111 km
    EXPECT_GT(response.distanceMeters, 100000.0);
}

TEST_F(GeoEngineTest, DistanceZero) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.7749, -122.4194, 0.0);  // Exact location
    EngineResponse response = engine.processLocation(location);

    EXPECT_NEAR(response.distanceMeters, 0.0, 1.0);
}

// Test Adaptive Intervals - Speed Based
TEST_F(GeoEngineTest, StationaryInterval) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.7749, -122.4194, 0.5);  // Stationary
    EngineResponse response = engine.processLocation(location);

    // Stationary should be 60 seconds
    EXPECT_EQ(response.nextIntervalMs, 60000);
}

TEST_F(GeoEngineTest, WalkingInterval) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.7749, -122.4194, 2.5);  // Walking (2.5 m/s)
    EngineResponse response = engine.processLocation(location);

    // Walking should be 10 seconds
    EXPECT_EQ(response.nextIntervalMs, 10000);
}

TEST_F(GeoEngineTest, RunningInterval) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.7749, -122.4194, 7.5);  // Running (7.5 m/s)
    EngineResponse response = engine.processLocation(location);

    // Running should be 5 seconds
    EXPECT_EQ(response.nextIntervalMs, 5000);
}

TEST_F(GeoEngineTest, VehicleInterval) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.7749, -122.4194, 20.0);  // Vehicle (20 m/s = 72 km/h)
    EngineResponse response = engine.processLocation(location);

    // Vehicle should be 2 seconds
    EXPECT_EQ(response.nextIntervalMs, 2000);
}

// Test Adaptive Intervals - Distance Based
TEST_F(GeoEngineTest, FarFromZoneDoubleInterval) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.75, -122.4194, 1.0);  // Far from zone
    EngineResponse response = engine.processLocation(location);

    // Far from zone should double the interval
    // Stationary (60000) * 2 = 120000
    EXPECT_EQ(response.nextIntervalMs, 120000);
}

TEST_F(GeoEngineTest, NearZoneMinInterval) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.77659, -122.4194, 5.0);  // Near zone, running speed
    EngineResponse response = engine.processLocation(location);

    // Near zone should be clamped to 5000ms
    EXPECT_EQ(response.nextIntervalMs, 5000);
}

// Test Interval Bounds
TEST_F(GeoEngineTest, MinIntervalBound) {
    // Very fast movement
    engine.addZone({37.7749, -122.4194, 100000.0});

    UserLocation location(37.7749, -122.4194, 50.0);  // Very fast
    EngineResponse response = engine.processLocation(location);

    // Should not go below 1000ms
    EXPECT_GE(response.nextIntervalMs, 1000);
}

TEST_F(GeoEngineTest, MaxIntervalBound) {
    engine.addZone({37.7749, -122.4194, 1000.0});

    UserLocation location(37.5, -122.0, 0.0);  // Far from zone, stationary
    EngineResponse response = engine.processLocation(location);

    // Should not exceed 120000ms
    EXPECT_LE(response.nextIntervalMs, 120000);
}

// Test Empty Zone
TEST_F(GeoEngineTest, NoZonesProcessLocation) {
    UserLocation location(37.7749, -122.4194, 0.0);
    EngineResponse response = engine.processLocation(location);

    EXPECT_FALSE(response.isInsideZone);
    EXPECT_EQ(response.nextIntervalMs, 60000);  // Default
    EXPECT_EQ(response.distanceMeters, 0.0);
}

// Test Nearest Zone Detection
TEST_F(GeoEngineTest, NearestZoneDetection) {
    engine.addZone({37.7749, -122.4194, 1000.0});   // SF
    engine.addZone({34.0522, -118.2437, 1000.0});   // LA (much farther)

    UserLocation location(37.7749, -122.4194, 0.0);  // At SF
    EngineResponse response = engine.processLocation(location);

    // Should return distance to SF (0), not LA
    EXPECT_NEAR(response.distanceMeters, 0.0, 1.0);
}

// Test Data Structures
TEST_F(GeoEngineTest, UserLocationConstruction) {
    UserLocation loc1;
    EXPECT_EQ(loc1.latitude, 0.0);
    EXPECT_EQ(loc1.longitude, 0.0);
    EXPECT_EQ(loc1.speedMps, 0.0);

    UserLocation loc2(37.7749, -122.4194, 5.0);
    EXPECT_EQ(loc2.latitude, 37.7749);
    EXPECT_EQ(loc2.longitude, -122.4194);
    EXPECT_EQ(loc2.speedMps, 5.0);
}

TEST_F(GeoEngineTest, GeofenceZoneConstruction) {
    GeofenceZone zone1;
    EXPECT_EQ(zone1.id, "");
    EXPECT_EQ(zone1.latitude, 0.0);
    EXPECT_EQ(zone1.longitude, 0.0);
    EXPECT_EQ(zone1.radiusMeters, 0.0);
    EXPECT_TRUE(zone1.notifyOnEntry);
    EXPECT_TRUE(zone1.notifyOnExit);

    GeofenceZone zone2(37.7749, -122.4194, 1000.0);
    EXPECT_EQ(zone2.id, "");
    EXPECT_EQ(zone2.latitude, 37.7749);
    EXPECT_EQ(zone2.longitude, -122.4194);
    EXPECT_EQ(zone2.radiusMeters, 1000.0);

    GeofenceZone zone3("home", 37.7749, -122.4194, 1000.0, true, false);
    EXPECT_EQ(zone3.id, "home");
    EXPECT_TRUE(zone3.notifyOnEntry);
    EXPECT_FALSE(zone3.notifyOnExit);
}

TEST_F(GeoEngineTest, EngineResponseDefaults) {
    EngineResponse response;
    EXPECT_FALSE(response.isInsideZone);
    EXPECT_EQ(response.nextIntervalMs, 60000);
    EXPECT_EQ(response.distanceMeters, 0.0);
    EXPECT_TRUE(response.transitions.empty());
}

TEST_F(GeoEngineTest, EmitsPerZoneEnterExitTransitionsOnce) {
    engine.addZone({"home", 37.7749, -122.4194, 1000.0});

    EngineResponse enter = engine.processLocation({37.7749, -122.4194, 0.0});
    ASSERT_EQ(enter.transitions.size(), 1);
    EXPECT_EQ(enter.transitions[0].zoneId, "home");
    EXPECT_TRUE(enter.transitions[0].isInside);

    EngineResponse duplicateEnter = engine.processLocation({37.7749, -122.4194, 0.0});
    EXPECT_TRUE(duplicateEnter.transitions.empty());

    EngineResponse exit = engine.processLocation({37.8, -122.5, 0.0});
    ASSERT_EQ(exit.transitions.size(), 1);
    EXPECT_EQ(exit.transitions[0].zoneId, "home");
    EXPECT_FALSE(exit.transitions[0].isInside);
}

TEST_F(GeoEngineTest, TriggerFlagsSuppressNotificationsButKeepState) {
    engine.addZone({"arrival-only", 37.7749, -122.4194, 1000.0, true, false});

    EngineResponse enter = engine.processLocation({37.7749, -122.4194, 0.0});
    ASSERT_EQ(enter.transitions.size(), 1);
    EXPECT_TRUE(enter.transitions[0].isInside);

    EngineResponse exit = engine.processLocation({37.8, -122.5, 0.0});
    EXPECT_TRUE(exit.transitions.empty());

    EngineResponse reenter = engine.processLocation({37.7749, -122.4194, 0.0});
    ASSERT_EQ(reenter.transitions.size(), 1);
    EXPECT_TRUE(reenter.transitions[0].isInside);
}

TEST_F(GeoEngineTest, PlatformZoneStateUpdatesUseSameDedup) {
    engine.addZone({"office", 37.7749, -122.4194, 1000.0});

    ZoneTransition transition;
    EXPECT_TRUE(engine.updateZoneState("office", true, transition));
    EXPECT_EQ(transition.zoneId, "office");
    EXPECT_TRUE(transition.isInside);

    ZoneTransition duplicate;
    EXPECT_FALSE(engine.updateZoneState("office", true, duplicate));

    ZoneTransition exit;
    EXPECT_TRUE(engine.updateZoneState("office", false, exit));
    EXPECT_EQ(exit.zoneId, "office");
    EXPECT_FALSE(exit.isInside);
}

TEST_F(GeoEngineTest, NearestZonesAreSortedByDistance) {
    engine.addZone({"far", 40.7128, -74.0060, 1000.0});
    engine.addZone({"near", 37.7749, -122.4194, 1000.0});

    auto nearest = engine.nearestZones(37.7750, -122.4194, 2);
    ASSERT_EQ(nearest.size(), 2);
    EXPECT_EQ(nearest[0].zoneId, "near");
    EXPECT_EQ(nearest[1].zoneId, "far");
    EXPECT_LT(nearest[0].distanceMeters, nearest[1].distanceMeters);
}

TEST_F(GeoEngineTest, SignificantMovementThreshold) {
    EXPECT_FALSE(engine.hasMovedSignificantly(
        37.7749, -122.4194,
        37.7750, -122.4194,
        500.0
    ));

    EXPECT_TRUE(engine.hasMovedSignificantly(
        37.7749, -122.4194,
        37.7849, -122.4194,
        500.0
    ));
}

TEST_F(NavigationHistoryEngineTest, RoutePointFilterKeepsUsefulPath) {
    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(1000, 23.7800, 90.4100, 0.0)
    ));

    EXPECT_FALSE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(11000, 23.78001, 90.41001, 0.0)
    ));

    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(70000, 23.78001, 90.41001, 0.0)
    ));

    HistoryDay day;
    ASSERT_TRUE(history.loadDay(directory, "2026-05-21", day));
    EXPECT_EQ(day.points.size(), 2);
    EXPECT_EQ(day.summary.pointCount, 2);
}

TEST_F(NavigationHistoryEngineTest, AlertEventsArePersistedInDay) {
    HistoryAlertEvent event;
    event.id = "event-1";
    event.alertId = "alert-1";
    event.task = "Buy groceries";
    event.place = "Market";
    event.address = "Dhaka";
    event.eventType = "Arriving";
    event.timestampMs = 2000;
    event.latitude = 23.7800;
    event.longitude = 90.4100;

    EXPECT_TRUE(history.appendAlertEvent(directory, "2026-05-21", event));

    HistoryDay day;
    ASSERT_TRUE(history.loadDay(directory, "2026-05-21", day));
    ASSERT_EQ(day.alertEvents.size(), 1);
    EXPECT_EQ(day.alertEvents[0].task, "Buy groceries");
    EXPECT_EQ(day.summary.alertEventCount, 1);
}

TEST_F(NavigationHistoryEngineTest, ListsSummariesAndPrunesOldDays) {
    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-19",
        HistoryRoutePoint(1000, 23.7800, 90.4100, 0.0)
    ));
    EXPECT_TRUE(history.appendRoutePoint(
        directory,
        "2026-05-21",
        HistoryRoutePoint(2000, 23.7900, 90.4200, 0.0)
    ));

    auto summaries = history.listDaySummaries(directory);
    ASSERT_EQ(summaries.size(), 2);
    EXPECT_EQ(summaries[0].dayKey, "2026-05-21");
    EXPECT_EQ(summaries[1].dayKey, "2026-05-19");

    EXPECT_EQ(history.pruneBeforeDay(directory, "2026-05-20"), 1);
    summaries = history.listDaySummaries(directory);
    ASSERT_EQ(summaries.size(), 1);
    EXPECT_EQ(summaries[0].dayKey, "2026-05-21");
}

// Integration Tests
TEST_F(GeoEngineTest, FullTrackingScenario) {
    // Add zones
    engine.addZone({37.7749, -122.4194, 1000.0});  // SF
    engine.addZone({34.0522, -118.2437, 1000.0});  // LA

    // Start at zone 1
    UserLocation loc1(37.7749, -122.4194, 5.0);
    EngineResponse resp1 = engine.processLocation(loc1);
    EXPECT_TRUE(resp1.isInsideZone);
    EXPECT_EQ(resp1.nextIntervalMs, 5000);  // Running speed

    // Move away while walking
    UserLocation loc2(37.78, -122.42, 1.5);
    EngineResponse resp2 = engine.processLocation(loc2);
    EXPECT_TRUE(resp2.isInsideZone);  // Still inside
    EXPECT_EQ(resp2.nextIntervalMs, 10000);  // Walking speed

    // Move far away
    UserLocation loc3(37.5, -122.0, 0.0);
    EngineResponse resp3 = engine.processLocation(loc3);
    EXPECT_FALSE(resp3.isInsideZone);  // Outside
    EXPECT_GE(resp3.nextIntervalMs, 60000);  // Doubled interval
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
