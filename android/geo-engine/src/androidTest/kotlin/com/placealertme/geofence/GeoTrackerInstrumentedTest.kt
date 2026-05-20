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
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.addZone(37.7749, -122.4194, 1000.0)

        val response = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0)

        assertTrue(response.isInsideZone)
        assertTrue(response.distanceMeters < 10.0)
        assertTrue(response.nextIntervalMs > 0)
    }

    @Test
    fun testOutsideZone() {
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()
        GeoEngineJNI.addZone(37.7749, -122.4194, 1000.0)

        val response = GeoEngineJNI.processLocationWrapped(37.5, -122.0, 0.0)

        assertFalse(response.isInsideZone)
        assertTrue(response.distanceMeters > 1000.0)
    }

    @Test
    fun testSpeedBasedInterval() {
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()
        GeoEngineJNI.addZone(37.7749, -122.4194, 1000.0)

        // Stationary
        val stationaryResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.5)
        assertTrue(stationaryResponse.nextIntervalMs >= 50000)  // ~60000

        // Walking
        val walkingResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 2.5)
        assertTrue(walkingResponse.nextIntervalMs < 20000)  // ~10000

        // Running
        val runningResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 7.5)
        assertTrue(runningResponse.nextIntervalMs < 10000)  // ~5000

        // Vehicle
        val vehicleResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 20.0)
        assertTrue(vehicleResponse.nextIntervalMs < 5000)  // ~2000
    }

    @Test
    fun testMultipleZones() {
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()

        // Add three zones
        GeoEngineJNI.addZone(37.7749, -122.4194, 1000.0)   // SF
        GeoEngineJNI.addZone(34.0522, -118.2437, 1000.0)   // LA
        GeoEngineJNI.addZone(40.7128, -74.0060, 1000.0)    // NYC

        val count = GeoEngineJNI.getZoneCount()
        assertEquals(3, count)

        // Test location in each zone
        val sfResponse = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0)
        assertTrue(sfResponse.isInsideZone)

        val laResponse = GeoEngineJNI.processLocationWrapped(34.0522, -118.2437, 0.0)
        assertTrue(laResponse.isInsideZone)

        val nycResponse = GeoEngineJNI.processLocationWrapped(40.7128, -74.0060, 0.0)
        assertTrue(nycResponse.isInsideZone)
    }

    @Test
    fun testZoneClear() {
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.addZone(37.7749, -122.4194, 1000.0)
        GeoEngineJNI.addZone(34.0522, -118.2437, 1000.0)

        assertEquals(2, GeoEngineJNI.getZoneCount())

        GeoEngineJNI.clearZones()

        assertEquals(0, GeoEngineJNI.getZoneCount())
    }

    @Test
    fun testEngineResponseData() {
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()
        GeoEngineJNI.addZone(37.7749, -122.4194, 1000.0)

        val response = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 2.5)

        assertNotNull(response)
        assertTrue(response.isInsideZone)
        assertTrue(response.distanceMeters >= 0.0)
        assertTrue(response.nextIntervalMs > 0)
    }

    @Test
    fun testTrackerIntegration() {
        tracker.addGeofenceZone(37.7749, -122.4194, 1000.0)
        assertEquals(1, tracker.getZoneCount())

        tracker.addGeofenceZone(34.0522, -118.2437, 1000.0)
        assertEquals(2, tracker.getZoneCount())

        tracker.clearGeofenceZones()
        assertEquals(0, tracker.getZoneCount())
    }

    @Test
    fun testServiceStartStop() {
        try {
            tracker.startTracking()
            Thread.sleep(100)  // Give service time to start
            tracker.stopTracking()
            Thread.sleep(100)  // Give service time to stop
            assertTrue(true)
        } catch (e: Exception) {
            fail("Service start/stop failed: ${e.message}")
        }
    }

    @Test
    fun testDistanceCalculation() {
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()

        // Add zone at origin
        GeoEngineJNI.addZone(0.0, 0.0, 1000.0)

        // Test location 1 degree away (approximately 111 km)
        val response = GeoEngineJNI.processLocationWrapped(0.0, 1.0, 0.0)

        assertTrue(response.distanceMeters > 100000.0)  // > 100 km
        assertTrue(response.distanceMeters < 120000.0)  // < 120 km
        assertFalse(response.isInsideZone)
    }
}
