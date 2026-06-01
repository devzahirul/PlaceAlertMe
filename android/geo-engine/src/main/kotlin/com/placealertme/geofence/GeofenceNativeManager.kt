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
            // DWELL (not bare ENTER) is the confirmed-arrival event: the OS only
            // fires it after the user has loitered inside for setLoiteringDelay ms,
            // matching the engine's 10s entry dwell. EXIT fires on boundary crossing
            // and is cross-validated (buffer + dwell) by the C++ engine on the wake-up fix.
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_DWELL or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setLoiteringDelay(10_000)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_DWELL)
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
        // Deliver to a BroadcastReceiver (not getService): background service
        // starts are blocked on Android O+, so a geofence transition fired while
        // the app is terminated would otherwise be dropped. The receiver hands
        // the work off to GeofenceTransitionService via enqueueWork (JobScheduler).
        val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }
}
