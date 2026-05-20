package com.placealertme.geofence

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Main public API for geofencing functionality
 * Use this to integrate PlaceAlertMe geofencing into your app
 */
class GeoTracker(private val context: Context) {

    init {
        GeoEngineJNI.initializeEngine()
    }

    /**
     * Start tracking location and activity
     * Requires location and activity recognition permissions
     */
    fun startTracking() {
        val intent = Intent(context, LocationTrackingService::class.java)
        ContextCompat.startForegroundService(context, intent)
    }

    /**
     * Stop all tracking
     */
    fun stopTracking() {
        val intent = Intent(context, LocationTrackingService::class.java)
        context.stopService(intent)
    }

    /**
     * Add a circular geofence zone
     * @param latitude Zone center latitude
     * @param longitude Zone center longitude
     * @param radiusMeters Zone radius in meters
     */
    fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        GeoEngineJNI.addZone(latitude, longitude, radiusMeters)
    }

    /**
     * Remove all geofence zones
     */
    fun clearGeofenceZones() {
        GeoEngineJNI.clearZones()
    }

    /**
     * Get number of active zones
     */
    fun getZoneCount(): Int {
        return GeoEngineJNI.getZoneCount()
    }

    /**
     * Pause location tracking (service continues running)
     */
    fun pauseTracking() {
        val intent = Intent(context, LocationTrackingService::class.java).apply {
            action = "com.placealertme.ACTION_PAUSE"
        }
        ContextCompat.startForegroundService(context, intent)
    }

    /**
     * Resume location tracking
     */
    fun resumeTracking() {
        val intent = Intent(context, LocationTrackingService::class.java).apply {
            action = "com.placealertme.ACTION_RESUME"
        }
        ContextCompat.startForegroundService(context, intent)
    }

    companion object {
        // Broadcast action for zone status changes
        const val ACTION_ZONE_STATUS_CHANGED = "com.placealertme.ZONE_STATUS_CHANGED"

        // Extras in the broadcast
        const val EXTRA_IS_INSIDE = "isInside"
        const val EXTRA_DISTANCE = "distance"
        const val EXTRA_NEXT_INTERVAL = "nextInterval"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
    }
}
