package com.placealertme.geofence

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

internal object GeofenceNativeManager {

    fun addZone(context: Context, id: String, latitude: Double, longitude: Double, radiusMeters: Double) {
        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radiusMeters.toFloat().coerceAtLeast(150f))
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setLoiteringDelay(10_000)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        try {
            LocationServices.getGeofencingClient(context)
                .addGeofences(request, getTransitionPendingIntent(context))
        } catch (_: SecurityException) {}
    }

    fun removeZone(context: Context, id: String) {
        LocationServices.getGeofencingClient(context).removeGeofences(listOf(id))
    }

    fun removeAll(context: Context) {
        LocationServices.getGeofencingClient(context)
            .removeGeofences(getTransitionPendingIntent(context))
    }

    private fun getTransitionPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, GeofenceTransitionService::class.java)
        return PendingIntent.getService(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }
}
