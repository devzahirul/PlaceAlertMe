package com.placealertme.geofence

import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import com.placealertme.geofence.GeoEngineJNI
import org.junit.Assert.*

@RunWith(AndroidJUnit4::class)
class GeoTrackerTest {

    private lateinit var context: Context
    private lateinit var tracker: GeoTracker

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        tracker = GeoTracker(context)
    }

    @Test
    fun testInitialization() {
        assertNotNull(tracker)
    }

    @Test
    fun testAddZone() {
        tracker.addGeofenceZone(37.7749, -122.4194, 1000.0)
        val count = tracker.getZoneCount()
        assertEquals(1, count)
    }

    @Test
    fun testAddMultipleZones() {
        tracker.addGeofenceZone(37.7749, -122.4194, 1000.0)  // SF
        tracker.addGeofenceZone(34.0522, -118.2437, 1000.0)  // LA
        tracker.addGeofenceZone(40.7128, -74.0060, 1000.0)   // NYC

        val count = tracker.getZoneCount()
        assertEquals(3, count)
    }

    @Test
    fun testClearZones() {
        tracker.addGeofenceZone(37.7749, -122.4194, 1000.0)
        tracker.addGeofenceZone(34.0522, -118.2437, 1000.0)

        assertEquals(2, tracker.getZoneCount())

        tracker.clearGeofenceZones()

        assertEquals(0, tracker.getZoneCount())
    }

    @Test
    fun testStartTracking() {
        // Should not throw exception
        try {
            tracker.startTracking()
        } catch (e: Exception) {
            fail("startTracking should not throw: ${e.message}")
        }
    }

    @Test
    fun testStopTracking() {
        tracker.startTracking()

        try {
            tracker.stopTracking()
        } catch (e: Exception) {
            fail("stopTracking should not throw: ${e.message}")
        }
    }

    @Test
    fun testPauseResumeTracking() {
        tracker.startTracking()

        try {
            tracker.pauseTracking()
            tracker.resumeTracking()
        } catch (e: Exception) {
            fail("Pause/Resume should not throw: ${e.message}")
        }
    }

    @Test
    fun testBroadcastConstants() {
        assertEquals("com.placealertme.ZONE_STATUS_CHANGED", GeoTracker.ACTION_ZONE_STATUS_CHANGED)
        assertEquals("isInside", GeoTracker.EXTRA_IS_INSIDE)
        assertEquals("distance", GeoTracker.EXTRA_DISTANCE)
        assertEquals("nextInterval", GeoTracker.EXTRA_NEXT_INTERVAL)
    }
}
