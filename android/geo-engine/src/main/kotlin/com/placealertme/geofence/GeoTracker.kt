package com.placealertme.geofence

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID

class GeoTracker(private val context: Context) {

    init {
        GeoEngineJNI.initializeEngine()
        restoreZonesFromDb()
    }

    fun startTracking() {
        val intent = Intent(context, LocationTrackingService::class.java)
        ContextCompat.startForegroundService(context, intent)
    }

    fun stopTracking() {
        val intent = Intent(context, LocationTrackingService::class.java)
        context.stopService(intent)
    }

    // Named-place API (Life360-style)
    fun addGeofenceZone(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) {
        GeoEngineJNI.addZone(id, name, latitude, longitude, radiusMeters)
        GeofenceNativeManager.addZone(context, id, latitude, longitude, radiusMeters)
        persistZone(id, name, latitude, longitude, radiusMeters)
    }

    // Deprecated overload — generates a UUID id for backwards compatibility
    @Deprecated("Prefer addGeofenceZone(id, name, lat, lon, radius)")
    fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        addGeofenceZone(UUID.randomUUID().toString(), "Zone", latitude, longitude, radiusMeters)
    }

    fun removeGeofenceZone(id: String) {
        GeoEngineJNI.removeZoneById(id)
        GeofenceNativeManager.removeZone(context, id)
        CoroutineScope(Dispatchers.IO).launch {
            GeofenceDatabase.getInstance(context).zoneDao().deleteById(id)
        }
    }

    fun clearGeofenceZones() {
        GeoEngineJNI.clearZones()
        GeofenceNativeManager.removeAll(context)
        CoroutineScope(Dispatchers.IO).launch {
            GeofenceDatabase.getInstance(context).zoneDao().deleteAll()
        }
    }

    fun getZoneCount(): Int = GeoEngineJNI.getZoneCount()

    fun pauseTracking() {
        val intent = Intent(context, LocationTrackingService::class.java).apply {
            action = "com.placealertme.ACTION_PAUSE"
        }
        ContextCompat.startForegroundService(context, intent)
    }

    fun resumeTracking() {
        val intent = Intent(context, LocationTrackingService::class.java).apply {
            action = "com.placealertme.ACTION_RESUME"
        }
        ContextCompat.startForegroundService(context, intent)
    }

    private fun persistZone(id: String, name: String, lat: Double, lon: Double, radius: Double) {
        CoroutineScope(Dispatchers.IO).launch {
            GeofenceDatabase.getInstance(context).zoneDao().insert(
                GeofenceZoneEntity(id, name, lat, lon, radius)
            )
        }
    }

    private fun restoreZonesFromDb() {
        CoroutineScope(Dispatchers.IO).launch {
            val zones = GeofenceDatabase.getInstance(context).zoneDao().getAll()
            zones.forEach { z ->
                GeoEngineJNI.addZone(z.id, z.name, z.latitude, z.longitude, z.radiusMeters)
                GeofenceNativeManager.addZone(context, z.id, z.latitude, z.longitude, z.radiusMeters)
            }
        }
    }

    companion object {
        // Per-zone transition broadcasts (new)
        const val ACTION_ZONE_ENTER = "com.placealertme.ZONE_ENTER"
        const val ACTION_ZONE_EXIT  = "com.placealertme.ZONE_EXIT"
        const val EXTRA_ZONE_ID     = "zoneId"
        const val EXTRA_ZONE_NAME   = "zoneName"
        const val EXTRA_TIMESTAMP   = "timestamp"

        // Global status broadcast (kept for backwards compat)
        const val ACTION_ZONE_STATUS_CHANGED = "com.placealertme.ZONE_STATUS_CHANGED"
        const val EXTRA_IS_INSIDE            = "isInside"
        const val EXTRA_DISTANCE             = "distance"
        const val EXTRA_NEXT_INTERVAL        = "nextInterval"
        const val EXTRA_LATITUDE             = "latitude"
        const val EXTRA_LONGITUDE            = "longitude"
    }
}
