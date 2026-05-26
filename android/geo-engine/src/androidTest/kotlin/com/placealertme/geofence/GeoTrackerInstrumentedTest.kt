package com.placealertme.geofence

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*

@RunWith(AndroidJUnit4::class)
class GeoTrackerInstrumentedTest {

    private lateinit var context: Context
    private lateinit var tracker: GeoTracker

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        tracker = GeoTracker(context)
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()
    }

    // Drive a zone to INSIDE state by simulating 11s dwell time.
    private fun driveInside(lat: Double, lon: Double, startMs: Long = 0L): GeoEngineJNI.EngineResponse {
        GeoEngineJNI.processLocationWrapped(lat, lon, 0.0, 10.0, startMs)
        return GeoEngineJNI.processLocationWrapped(lat, lon, 0.0, 10.0, startMs + 11000L)
    }

    @Test
    fun testContextInitialization() {
        assertNotNull(context)
        assertNotNull(tracker)
    }

    @Test
    fun testGeoEngineJNIInitialization() {
        try {
            GeoEngineJNI.initializeEngine()
            assertTrue(true)
        } catch (e: Exception) {
            fail("JNI initialization failed: ${e.message}")
        }
    }

    @Test
    fun testAddAndProcessZone() {
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)

        val response = driveInside(37.7749, -122.4194)

        assertTrue("Should be inside after dwell", response.isInsideAnyZone)
        assertTrue("Distance at center should be ~0m", response.distanceToNearestMeters < 10.0)
        assertTrue("Interval should be positive", response.nextIntervalMs > 0)
    }

    @Test
    fun testOutsideZone() {
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)

        val response = GeoEngineJNI.processLocationWrapped(37.5, -122.0, 0.0, 10.0, 0L)

        assertFalse("Far location should be outside", response.isInsideAnyZone)
        assertTrue("Distance should be > 1000m", response.distanceToNearestMeters > 1000.0)
    }

    @Test
    fun testDwellTimeEntry() {
        GeoEngineJNI.addZone("z1", "Zone", 37.7749, -122.4194, 200.0)

        // First fix — PENDING_ENTER, no transition yet
        val r1 = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0, 10.0, 0L)
        assertFalse("First fix should be PENDING_ENTER, not inside", r1.isInsideAnyZone)
        assertTrue("No transition before dwell", r1.transitions.isEmpty())

        // After dwell — INSIDE, ENTER event
        val r2 = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0, 10.0, 11000L)
        assertTrue("Should be inside after 10s dwell", r2.isInsideAnyZone)
        assertEquals("One ENTER transition expected", 1, r2.transitions.size)
        assertEquals("Transition type should be ENTER", "ENTER", r2.transitions.first().type)
    }

    @Test
    fun testAccuracyGating() {
        GeoEngineJNI.addZone("z1", "Zone", 37.7749, -122.4194, 200.0)

        val response = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0, 70.0, 0L)
        assertEquals("Poor accuracy should return 5s wait interval", 5000L, response.nextIntervalMs)
        assertTrue("No transitions when accuracy is poor", response.transitions.isEmpty())
    }

    @Test
    fun testMinimumRadiusEnforced() {
        // 50m radius → enforced to 150m
        GeoEngineJNI.addZone("z1", "Zone", 37.7749, -122.4194, 50.0)

        // ~100m north (0.0009° × 111000 m/° ≈ 100m): inside 150m, outside 50m
        val response = driveInside(37.7758, -122.4194)
        assertTrue("100m point should be inside zone with enforced 150m radius", response.isInsideAnyZone)
    }

    @Test
    fun testSpeedBasedInterval() {
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)

        // Stationary (inside zone — speed-only interval)
        val stationaryResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.5, 10.0, 0L)
        assertTrue("Stationary ~60s", stationaryResponse.nextIntervalMs >= 50000)

        // Walking
        val walkingResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 2.5, 10.0, 0L)
        assertTrue("Walking ~10s", walkingResponse.nextIntervalMs < 20000)

        // Running
        val runningResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 7.5, 10.0, 0L)
        assertTrue("Running ~5s", runningResponse.nextIntervalMs < 10000)

        // Vehicle
        val vehicleResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 20.0, 10.0, 0L)
        assertTrue("Vehicle ~2s", vehicleResponse.nextIntervalMs < 5000)
    }

    @Test
    fun testMultipleZones() {
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)
        GeoEngineJNI.addZone("la", "Los Angeles", 34.0522, -118.2437, 1000.0)
        GeoEngineJNI.addZone("nyc", "New York", 40.7128, -74.0060, 1000.0)

        assertEquals(3, GeoEngineJNI.getZoneCount())
    }

    @Test
    fun testMultipleZoneIndependentEntry() {
        // SF zone
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)
        val sfResponse = driveInside(37.7749, -122.4194)
        assertTrue("Should be inside SF after dwell", sfResponse.isInsideAnyZone)

        // LA zone (independent clear)
        GeoEngineJNI.clearZones()
        GeoEngineJNI.addZone("la", "Los Angeles", 34.0522, -118.2437, 1000.0)
        val laResponse = driveInside(34.0522, -118.2437)
        assertTrue("Should be inside LA after dwell", laResponse.isInsideAnyZone)
    }

    @Test
    fun testZoneClear() {
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)
        GeoEngineJNI.addZone("la", "Los Angeles", 34.0522, -118.2437, 1000.0)
        assertEquals(2, GeoEngineJNI.getZoneCount())

        GeoEngineJNI.clearZones()
        assertEquals(0, GeoEngineJNI.getZoneCount())
    }

    @Test
    fun testEngineResponseData() {
        GeoEngineJNI.addZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)

        val response = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 2.5, 10.0, 0L)

        assertNotNull(response)
        assertTrue("Distance should be non-negative", response.distanceToNearestMeters >= 0.0)
        assertTrue("Interval should be positive", response.nextIntervalMs > 0)
    }

    @Test
    fun testTrackerIntegration() {
        tracker.addGeofenceZone("sf", "San Francisco", 37.7749, -122.4194, 1000.0)
        assertEquals(1, tracker.getZoneCount())

        tracker.addGeofenceZone("la", "Los Angeles", 34.0522, -118.2437, 1000.0)
        assertEquals(2, tracker.getZoneCount())

        tracker.clearGeofenceZones()
        assertEquals(0, tracker.getZoneCount())
    }

    @Test
    fun testServiceStartStop() {
        try {
            tracker.startTracking()
            Thread.sleep(100)
            tracker.stopTracking()
            Thread.sleep(100)
            assertTrue(true)
        } catch (e: Exception) {
            fail("Service start/stop failed: ${e.message}")
        }
    }

    @Test
    fun testDistanceCalculation() {
        GeoEngineJNI.addZone("origin", "Origin", 0.0, 0.0, 1000.0)

        // 1 degree longitude at equator ≈ 111km
        val response = GeoEngineJNI.processLocationWrapped(0.0, 1.0, 0.0, 10.0, 0L)

        assertTrue("Distance should be > 100km", response.distanceToNearestMeters > 100000.0)
        assertTrue("Distance should be < 120km", response.distanceToNearestMeters < 120000.0)
        assertFalse("Should be outside 1km zone", response.isInsideAnyZone)
    }

    @Test
    fun testTransitionBroadcastConstants() {
        assertEquals("com.placealertme.ZONE_ENTER", GeoTracker.ACTION_ZONE_ENTER)
        assertEquals("com.placealertme.ZONE_EXIT", GeoTracker.ACTION_ZONE_EXIT)
        assertEquals("zoneId", GeoTracker.EXTRA_ZONE_ID)
        assertEquals("zoneName", GeoTracker.EXTRA_ZONE_NAME)
    }
}
