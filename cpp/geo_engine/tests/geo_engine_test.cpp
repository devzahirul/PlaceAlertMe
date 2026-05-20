#include <gtest/gtest.h>
#include "geo_engine.h"
#include <cmath>

using namespace geo_engine;

class GeoEngineTest : public ::testing::Test {
protected:
    GeoEngine engine;

    void SetUp() override {
        engine.clearZones();
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
    EXPECT_EQ(zone1.latitude, 0.0);
    EXPECT_EQ(zone1.longitude, 0.0);
    EXPECT_EQ(zone1.radiusMeters, 0.0);

    GeofenceZone zone2(37.7749, -122.4194, 1000.0);
    EXPECT_EQ(zone2.latitude, 37.7749);
    EXPECT_EQ(zone2.longitude, -122.4194);
    EXPECT_EQ(zone2.radiusMeters, 1000.0);
}

TEST_F(GeoEngineTest, EngineResponseDefaults) {
    EngineResponse response;
    EXPECT_FALSE(response.isInsideZone);
    EXPECT_EQ(response.nextIntervalMs, 60000);
    EXPECT_EQ(response.distanceMeters, 0.0);
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
