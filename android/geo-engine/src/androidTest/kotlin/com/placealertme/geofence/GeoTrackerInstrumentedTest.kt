package com.placealertme.geofence

import android.content.Context
import android.app.NotificationManager
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.*

@RunWith(AndroidJUnit4::class)
class GeoTrackerInstrumentedTest {

    private lateinit var context: Context
    private lateinit var tracker: GeoTracker
    private lateinit var testDb: GeofenceDatabase

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        tracker = GeoTracker(context)
        GeoEngineJNI.initializeEngine()
        GeoEngineJNI.clearZones()
        // In-memory DB for DAO tests (isolated from the singleton)
        testDb = Room.inMemoryDatabaseBuilder(context, GeofenceDatabase::class.java)
            .allowMainThreadQueries()
            .build()
    }

    @After
    fun tearDown() {
        testDb.close()
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

    // ─── PlaceVisitDao ────────────────────────────────────────────────────────

    @Test
    fun testPlaceVisitDaoInsert() = runBlocking {
        val dao = testDb.visitDao()
        val visit = PlaceVisitEntity(
            zoneId = "home", zoneName = "Home",
            arrivalTimestampMs = 1000L,
            arrivalLatitude = 37.7749, arrivalLongitude = -122.4194,
            arrivalSpeedMps = 0.0
        )
        val id = dao.insert(visit)
        assertTrue("Insert should return a positive row id", id > 0)

        val active = dao.getActiveVisits()
        assertEquals(1, active.size)
        assertEquals("home", active[0].zoneId)
        assertEquals("Home", active[0].zoneName)
        assertEquals(1000L, active[0].arrivalTimestampMs)
        assertEquals(-1L, active[0].departureTimestampMs) // still active
        assertTrue(active[0].isActive)
    }

    @Test
    fun testPlaceVisitDaoCloseVisit() = runBlocking {
        val dao = testDb.visitDao()
        dao.insert(PlaceVisitEntity(
            zoneId = "work", zoneName = "Work",
            arrivalTimestampMs = 5000L,
            arrivalLatitude = 37.7749, arrivalLongitude = -122.4194,
            arrivalSpeedMps = 0.5
        ))

        dao.closeVisit(zoneId = "work", departureMs = 65000L)

        val active = dao.getActiveVisits()
        assertEquals("No active visits after closeVisit", 0, active.size)

        val history = dao.getVisitHistory("work", limit = 10)
        assertEquals(1, history.size)
        assertFalse("Closed visit should not be active", history[0].isActive)
        assertEquals(65000L, history[0].departureTimestampMs)
        assertEquals(60000L, history[0].durationMs)
    }

    @Test
    fun testPlaceVisitDaoActiveVsCompleted() = runBlocking {
        val dao = testDb.visitDao()
        // Insert two visits — close only the first
        dao.insert(PlaceVisitEntity(
            zoneId = "gym", zoneName = "Gym",
            arrivalTimestampMs = 1000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))
        dao.insert(PlaceVisitEntity(
            zoneId = "cafe", zoneName = "Cafe",
            arrivalTimestampMs = 2000L,
            arrivalLatitude = 1.0, arrivalLongitude = 1.0, arrivalSpeedMps = 0.0
        ))
        dao.closeVisit(zoneId = "gym", departureMs = 10000L)

        val active = dao.getActiveVisits()
        assertEquals("Only one visit should remain active", 1, active.size)
        assertEquals("cafe", active[0].zoneId)
    }

    @Test
    fun testPlaceVisitDaoHistoryOrdering() = runBlocking {
        val dao = testDb.visitDao()
        dao.insert(PlaceVisitEntity(
            zoneId = "home", zoneName = "Home",
            arrivalTimestampMs = 1000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))
        dao.insert(PlaceVisitEntity(
            zoneId = "home", zoneName = "Home",
            arrivalTimestampMs = 3000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))
        dao.insert(PlaceVisitEntity(
            zoneId = "home", zoneName = "Home",
            arrivalTimestampMs = 2000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))

        val history = dao.getVisitHistory("home", limit = 10)
        assertEquals(3, history.size)
        // Should be sorted newest-first
        assertTrue("History should be newest-first",
            history[0].arrivalTimestampMs >= history[1].arrivalTimestampMs)
        assertTrue(history[1].arrivalTimestampMs >= history[2].arrivalTimestampMs)
    }

    @Test
    fun testPlaceVisitDaoZoneIdFilter() = runBlocking {
        val dao = testDb.visitDao()
        dao.insert(PlaceVisitEntity(
            zoneId = "a", zoneName = "A",
            arrivalTimestampMs = 1000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))
        dao.insert(PlaceVisitEntity(
            zoneId = "b", zoneName = "B",
            arrivalTimestampMs = 2000L,
            arrivalLatitude = 1.0, arrivalLongitude = 1.0, arrivalSpeedMps = 0.0
        ))
        dao.insert(PlaceVisitEntity(
            zoneId = "a", zoneName = "A",
            arrivalTimestampMs = 3000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))

        val historyA = dao.getVisitHistory("a", limit = 10)
        assertEquals("Should return only zone 'a' visits", 2, historyA.size)
        assertTrue(historyA.all { it.zoneId == "a" })
    }

    @Test
    fun testPlaceVisitDaoPruneOlderThan() = runBlocking {
        val dao = testDb.visitDao()
        dao.insert(PlaceVisitEntity(
            zoneId = "old", zoneName = "Old",
            arrivalTimestampMs = 100L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))
        dao.insert(PlaceVisitEntity(
            zoneId = "new", zoneName = "New",
            arrivalTimestampMs = 9000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        ))

        dao.pruneOlderThan(beforeMs = 5000L)

        val all = dao.getAllVisitHistory(limit = 100)
        assertEquals("Old visit should be pruned", 1, all.size)
        assertEquals("new", all[0].zoneId)
    }

    @Test
    fun testPlaceVisitEntityIsActiveAndDuration() {
        val active = PlaceVisitEntity(
            zoneId = "z", zoneName = "Z",
            arrivalTimestampMs = 1000L,
            arrivalLatitude = 0.0, arrivalLongitude = 0.0, arrivalSpeedMps = 0.0
        )
        assertTrue(active.isActive)
        assertEquals(-1L, active.durationMs) // undefined while active

        val completed = active.copy(departureTimestampMs = 31000L)
        assertFalse(completed.isActive)
        assertEquals(30000L, completed.durationMs)
    }

    @Test
    fun testPlaceVisitArrivalCoordinates() = runBlocking {
        val dao = testDb.visitDao()
        dao.insert(PlaceVisitEntity(
            zoneId = "london", zoneName = "London",
            arrivalTimestampMs = 5000L,
            arrivalLatitude = 51.5074, arrivalLongitude = -0.1278,
            arrivalSpeedMps = 1.2
        ))

        val visits = dao.getActiveVisits()
        assertEquals(51.5074,  visits[0].arrivalLatitude,  0.0001)
        assertEquals(-0.1278, visits[0].arrivalLongitude, 0.0001)
        assertEquals(1.2,      visits[0].arrivalSpeedMps,  0.01)
    }

    // ─── GeofenceNotificationManager ─────────────────────────────────────────

    @Test
    fun testGeofenceNotificationChannelCreation() {
        // Should not throw on any API level
        GeofenceNotificationManager.createChannel(context)

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val nm = context.getSystemService(NotificationManager::class.java)
            assertNotNull("Notification channel should exist after createChannel",
                nm.getNotificationChannel("placealertme_geofence"))
        }
    }

    @Test
    fun testGeofenceNotificationTitles() {
        // notifyEnter / notifyExit must not throw; we verify they construct without crash
        try {
            GeofenceNotificationManager.createChannel(context)
            GeofenceNotificationManager.notifyEnter(context, "home", "Home")
            GeofenceNotificationManager.notifyExit(context, "home", "Home")
            assertTrue(true)
        } catch (e: Exception) {
            fail("Notification calls should not throw: ${e.message}")
        }
    }

    // ─── GeoTracker API — zone count & broadcast constants ───────────────────

    @Test
    fun testGeoTrackerZoneCountAfterAdd() {
        GeoEngineJNI.clearZones()
        tracker.addGeofenceZone("t1", "T1", 37.7749, -122.4194, 200.0)
        tracker.addGeofenceZone("t2", "T2", 34.0522, -118.2437, 200.0)
        assertEquals(2, tracker.getZoneCount())

        tracker.removeGeofenceZone("t1")
        assertEquals(1, tracker.getZoneCount())

        tracker.clearGeofenceZones()
        assertEquals(0, tracker.getZoneCount())
    }

    @Test
    fun testTransitionContainsZoneName() {
        GeoEngineJNI.addZone("named", "My Place", 37.7749, -122.4194, 200.0)

        // After dwell, ENTER transition zoneName must match
        val r1 = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0, 10.0, 0L)
        val r2 = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0, 10.0, 11000L)

        assertTrue("Should be inside after dwell", r2.isInsideAnyZone)
        assertEquals(1, r2.transitions.size)
        assertEquals("My Place", r2.transitions.first().zoneName)
    }

    @Test
    fun testDwellExitTransition() {
        GeoEngineJNI.addZone("exit_test", "Exit Zone", 37.7749, -122.4194, 500.0)
        // Drive inside
        driveInside(37.7749, -122.4194, startMs = 0L)
        // Move far outside (>550m from center — beyond radius + 50m buffer)
        // 37.7849 is ~1113m north of 37.7749
        GeoEngineJNI.processLocationWrapped(37.7849, -122.4194, 0.0, 10.0, 12000L)
        val r = GeoEngineJNI.processLocationWrapped(37.7849, -122.4194, 0.0, 10.0, 23000L)

        assertEquals("One EXIT transition expected", 1, r.transitions.size)
        assertEquals("EXIT", r.transitions.first().type)
        assertEquals("exit_test", r.transitions.first().zoneId)
    }

    @Test
    fun testHysteresisNoExitWithinBuffer() {
        // Zone radius 500m, exit threshold = 500+50 = 550m
        GeoEngineJNI.addZone("hyst", "Hysteresis Zone", 37.7749, -122.4194, 500.0)
        driveInside(37.7749, -122.4194, startMs = 0L)

        // Move to ~520m from center (inside buffer): 37.7749 + 0.00468° ≈ 520m north
        val r = GeoEngineJNI.processLocationWrapped(37.7796, -122.4194, 0.0, 10.0, 12000L)

        assertTrue("Should remain inside zone within exit buffer", r.isInsideAnyZone)
        assertTrue("No EXIT transition within exit buffer", r.transitions.isEmpty())
    }

    @Test
    fun testPendingEnterCancelledBeforeDwell() {
        GeoEngineJNI.addZone("cancel", "Cancel Zone", 37.7749, -122.4194, 200.0)

        // First fix — enters PENDING_ENTER
        val r1 = GeoEngineJNI.processLocationWrapped(37.7749, -122.4194, 0.0, 10.0, 0L)
        assertFalse("Should not be inside yet (PENDING_ENTER)", r1.isInsideAnyZone)

        // Move outside before dwell completes
        val r2 = GeoEngineJNI.processLocationWrapped(37.5, -122.0, 0.0, 10.0, 5000L)
        assertFalse("Should be outside after leaving before dwell", r2.isInsideAnyZone)
        assertTrue("No ENTER event should fire", r2.transitions.isEmpty())
    }
}
