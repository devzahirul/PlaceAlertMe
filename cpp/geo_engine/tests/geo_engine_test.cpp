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

    // Helper: drive a location into a zone's INSIDE state by satisfying dwell
    void driveInside(const std::string& zoneId,
                     double lat, double lon) {
        engine.processLocation({lat, lon, 0.0, 10.0, 0});
        engine.processLocation({lat, lon, 0.0, 10.0, DWELL_ENTRY_MS});
    }
};

// ─── Zone Management ──────────────────────────────────────────────────────────

TEST_F(GeoEngineTest, AddZone) {
    EXPECT_EQ(engine.getZoneCount(), 0);
    engine.addZone({"sf", "San Francisco", 37.7749, -122.4194, 1000.0});
    EXPECT_EQ(engine.getZoneCount(), 1);
}

TEST_F(GeoEngineTest, AddMultipleZones) {
    engine.addZone({"sf", "San Francisco", 37.7749, -122.4194, 1000.0});
    engine.addZone({"la", "Los Angeles",   34.0522, -118.2437, 1000.0});
    engine.addZone({"ny", "New York",      40.7128,  -74.0060, 1000.0});
    EXPECT_EQ(engine.getZoneCount(), 3);
}

TEST_F(GeoEngineTest, ClearZones) {
    engine.addZone({"sf", "San Francisco", 37.7749, -122.4194, 1000.0});
    engine.addZone({"la", "Los Angeles",   34.0522, -118.2437, 1000.0});
    EXPECT_EQ(engine.getZoneCount(), 2);
    engine.clearZones();
    EXPECT_EQ(engine.getZoneCount(), 0);
}

TEST_F(GeoEngineTest, RemoveZone) {
    engine.addZone({"sf", "San Francisco", 37.7749, -122.4194, 1000.0});
    engine.addZone({"la", "Los Angeles",   34.0522, -118.2437, 1000.0});
    EXPECT_EQ(engine.getZoneCount(), 2);
    engine.removeZone("sf");
    EXPECT_EQ(engine.getZoneCount(), 1);
}

TEST_F(GeoEngineTest, ClearZonesClearsState) {
    engine.addZone({"sf", "San Francisco", 37.7749, -122.4194, 1000.0});
    driveInside("sf", 37.7749, -122.4194);
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::INSIDE);
    engine.clearZones();
    // After re-adding, state must start fresh
    engine.addZone({"sf", "San Francisco", 37.7749, -122.4194, 1000.0});
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::OUTSIDE);
}

// ─── Min Radius Enforcement ───────────────────────────────────────────────────

TEST_F(GeoEngineTest, MinRadiusEnforced) {
    engine.addZone({"tiny", "Tiny Zone", 37.7749, -122.4194, 50.0});
    // First call: inside if the 150m minimum is applied
    engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    EXPECT_EQ(engine.getZoneState("tiny"), ZoneState::PENDING_ENTER);
}

// ─── State Machine ────────────────────────────────────────────────────────────

TEST_F(GeoEngineTest, PendingEnterBeforeDwell) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    // First location inside zone — not yet INSIDE
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    EXPECT_FALSE(r.isInsideAnyZone);
    EXPECT_TRUE(r.transitions.empty());
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::PENDING_ENTER);
}

TEST_F(GeoEngineTest, EnterFiredAfterDwell) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 10.0, DWELL_ENTRY_MS});
    EXPECT_TRUE(r.isInsideAnyZone);
    EXPECT_EQ(r.transitions.size(), (size_t)1);
    EXPECT_EQ(r.transitions[0].type, TransitionType::ENTER);
    EXPECT_EQ(r.transitions[0].zoneId, "sf");
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::INSIDE);
}

TEST_F(GeoEngineTest, PendingEnterCancelledOnExit) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::PENDING_ENTER);
    // Move outside before dwell completes
    engine.processLocation({37.5, -122.0, 0.0, 10.0, 5000});
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::OUTSIDE);
}

TEST_F(GeoEngineTest, ExitFiredAfterDwell) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    driveInside("sf", 37.7749, -122.4194);
    // Move beyond exit threshold (radius + 50m buffer = 1050m)
    // Use a location ~1100m from center
    // 37.7849 is approx 1113m north of 37.7749
    engine.processLocation({37.7849, -122.4194, 0.0, 10.0, DWELL_ENTRY_MS + 1000});
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::PENDING_EXIT);
    auto r = engine.processLocation({37.7849, -122.4194, 0.0, 10.0,
                                      DWELL_ENTRY_MS + 1000 + DWELL_EXIT_MS});
    EXPECT_EQ(r.transitions.size(), (size_t)1);
    EXPECT_EQ(r.transitions[0].type, TransitionType::EXIT);
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::OUTSIDE);
}

TEST_F(GeoEngineTest, PendingExitCancelledOnReentry) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    driveInside("sf", 37.7749, -122.4194);
    // Trigger PENDING_EXIT
    engine.processLocation({37.7849, -122.4194, 0.0, 10.0, DWELL_ENTRY_MS + 1000});
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::PENDING_EXIT);
    // Return inside radius — cancel exit
    engine.processLocation({37.7749, -122.4194, 0.0, 10.0, DWELL_ENTRY_MS + 2000});
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::INSIDE);
}

// ─── Hysteresis ───────────────────────────────────────────────────────────────

TEST_F(GeoEngineTest, HysteresisInsideBuffer) {
    // Zone radius 1000m, exit threshold 1000+50=1050m
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    driveInside("sf", 37.7749, -122.4194);
    // Move to ~1020m from center (inside exit buffer)
    // 37.7749 + 0.00917 deg ≈ 1020m north
    engine.processLocation({37.7841, -122.4194, 0.0, 10.0, DWELL_ENTRY_MS + 1000});
    // Should still be INSIDE (not yet PENDING_EXIT — within buffer)
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::INSIDE);
}

// ─── Accuracy Gating ──────────────────────────────────────────────────────────

TEST_F(GeoEngineTest, PoorAccuracySkipsTransitions) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    // High inaccuracy fix — should return fast poll interval, no transitions
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 70.0, 0});
    EXPECT_TRUE(r.transitions.empty());
    EXPECT_EQ(r.nextIntervalMs, ACCURACY_WAIT_INTERVAL_MS);
    // State must not change
    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::OUTSIDE);
}

// ─── Distance Calculation ─────────────────────────────────────────────────────

TEST_F(GeoEngineTest, DistanceCalculation) {
    engine.addZone({"origin", "Origin", 0.0, 0.0, 1000.0});
    auto r = engine.processLocation({0.0, 1.0, 0.0, 10.0, 0});
    // 1 degree at equator ≈ 111 km
    EXPECT_GT(r.distanceToNearestMeters, 100000.0);
    EXPECT_LT(r.distanceToNearestMeters, 120000.0);
}

TEST_F(GeoEngineTest, DistanceZeroAtCenter) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    EXPECT_NEAR(r.distanceToNearestMeters, 0.0, 1.0);
}

TEST_F(GeoEngineTest, NearestZoneReturned) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    engine.addZone({"la", "LA", 34.0522, -118.2437, 1000.0});
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    EXPECT_NEAR(r.distanceToNearestMeters, 0.0, 1.0);
}

// ─── Adaptive Intervals ───────────────────────────────────────────────────────

TEST_F(GeoEngineTest, StationaryIntervalInsideZone) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    // Inside zone → speed only governs
    auto r = engine.processLocation({37.7749, -122.4194, 0.5, 10.0, 0});
    EXPECT_EQ(r.nextIntervalMs, 60000);
}

TEST_F(GeoEngineTest, WalkingIntervalInsideZone) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    auto r = engine.processLocation({37.7749, -122.4194, 2.5, 10.0, 0});
    EXPECT_EQ(r.nextIntervalMs, 10000);
}

TEST_F(GeoEngineTest, RunningIntervalInsideZone) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    auto r = engine.processLocation({37.7749, -122.4194, 7.5, 10.0, 0});
    EXPECT_EQ(r.nextIntervalMs, 5000);
}

TEST_F(GeoEngineTest, VehicleIntervalInsideZone) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    auto r = engine.processLocation({37.7749, -122.4194, 20.0, 10.0, 0});
    EXPECT_EQ(r.nextIntervalMs, 2000);
}

TEST_F(GeoEngineTest, FarFromZoneDoubleInterval) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 150.0});
    // (37.75, -122.4194) is ~2765m from center; distToBoundary ~2615m > 150*2=300 → doubled
    auto r = engine.processLocation({37.75, -122.4194, 0.5, 10.0, 0});
    EXPECT_EQ(r.nextIntervalMs, 120000);
}

TEST_F(GeoEngineTest, ApproachingZoneFasterInterval) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 150.0});
    // ~188m from center, radius 150m → distToBoundary ~38m (approaching)
    auto r = engine.processLocation({37.77659, -122.4194, 5.0, 10.0, 0});
    EXPECT_EQ(r.nextIntervalMs, 5000);
}

TEST_F(GeoEngineTest, MinIntervalBound) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 100000.0});
    auto r = engine.processLocation({37.7749, -122.4194, 50.0, 10.0, 0});
    EXPECT_GE(r.nextIntervalMs, 1000);
}

TEST_F(GeoEngineTest, MaxIntervalBound) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    auto r = engine.processLocation({37.5, -122.0, 0.0, 10.0, 0});
    EXPECT_LE(r.nextIntervalMs, 120000);
}

// ─── Empty Zones ──────────────────────────────────────────────────────────────

TEST_F(GeoEngineTest, NoZonesProcessLocation) {
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    EXPECT_FALSE(r.isInsideAnyZone);
    EXPECT_EQ(r.nextIntervalMs, 60000);
    EXPECT_TRUE(r.transitions.empty());
}

// ─── Per-Zone Independence ────────────────────────────────────────────────────

TEST_F(GeoEngineTest, TwoZonesIndependentState) {
    engine.addZone({"sf", "SF", 37.7749, -122.4194, 1000.0});
    engine.addZone({"la", "LA", 34.0522, -118.2437, 1000.0});

    // Drive into SF only
    driveInside("sf", 37.7749, -122.4194);

    EXPECT_EQ(engine.getZoneState("sf"), ZoneState::INSIDE);
    EXPECT_EQ(engine.getZoneState("la"), ZoneState::OUTSIDE);

    // Now drive into LA — SF should start exit dwell
    engine.processLocation({34.0522, -118.2437, 0.0, 10.0, DWELL_ENTRY_MS + 1000});
    EXPECT_EQ(engine.getZoneState("la"), ZoneState::PENDING_ENTER);
}

TEST_F(GeoEngineTest, MultipleTransitionsInOneFix) {
    engine.addZone({"a", "Zone A", 37.7749, -122.4194, 1000.0});
    engine.addZone({"b", "Zone B", 37.7749, -122.4194, 1000.0});  // Same location

    engine.processLocation({37.7749, -122.4194, 0.0, 10.0, 0});
    auto r = engine.processLocation({37.7749, -122.4194, 0.0, 10.0, DWELL_ENTRY_MS});

    // Both zones fire ENTER in the same fix
    EXPECT_EQ(r.transitions.size(), (size_t)2);
    EXPECT_EQ(r.transitions[0].type, TransitionType::ENTER);
    EXPECT_EQ(r.transitions[1].type, TransitionType::ENTER);
}

// ─── Data Structure Defaults ──────────────────────────────────────────────────

TEST_F(GeoEngineTest, EngineResponseDefaults) {
    EngineResponse r;
    EXPECT_FALSE(r.isInsideAnyZone);
    EXPECT_EQ(r.nextIntervalMs, 60000);
    EXPECT_EQ(r.distanceToNearestMeters, 0.0);
    EXPECT_TRUE(r.transitions.empty());
}

TEST_F(GeoEngineTest, UserLocationConstruction) {
    UserLocation l1;
    EXPECT_EQ(l1.latitude, 0.0);
    EXPECT_EQ(l1.longitude, 0.0);
    EXPECT_EQ(l1.speedMps, 0.0);
    EXPECT_EQ(l1.accuracyMeters, 0.0);
    EXPECT_EQ(l1.timestampMs, 0);

    UserLocation l2(37.7749, -122.4194, 5.0, 15.0, 12345);
    EXPECT_EQ(l2.latitude, 37.7749);
    EXPECT_EQ(l2.speedMps, 5.0);
    EXPECT_EQ(l2.accuracyMeters, 15.0);
    EXPECT_EQ(l2.timestampMs, 12345);
}

TEST_F(GeoEngineTest, GeofenceZoneMinRadius) {
    GeofenceZone z("id", "name", 0.0, 0.0, 50.0);
    EXPECT_EQ(z.radiusMeters, MIN_RADIUS_METERS);
    EXPECT_EQ(z.exitBufferMeters, EXIT_BUFFER_METERS);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
