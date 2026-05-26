package com.placealertme.geofence

import android.content.Context
import android.content.Intent
import androidx.core.app.JobIntentService
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.Geofence

internal class GeofenceTransitionService : JobIntentService() {

    override fun onHandleWork(intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return

        val transitionType = event.geofenceTransition
        val triggeringGeofences = event.triggeringGeofences ?: return

        for (geofence in triggeringGeofences) {
            val action = when (transitionType) {
                Geofence.GEOFENCE_TRANSITION_ENTER -> GeoTracker.ACTION_ZONE_ENTER
                Geofence.GEOFENCE_TRANSITION_EXIT  -> GeoTracker.ACTION_ZONE_EXIT
                else -> continue
            }
            // Broadcast the OS-triggered transition; C++ engine state will
            // be cross-validated on the next location fix via processLocationWrapped.
            sendBroadcast(Intent(action).apply {
                putExtra(GeoTracker.EXTRA_ZONE_ID,   geofence.requestId)
                putExtra(GeoTracker.EXTRA_ZONE_NAME, geofence.requestId)
                putExtra(GeoTracker.EXTRA_TIMESTAMP, System.currentTimeMillis())
            })
        }
    }

    companion object {
        private const val JOB_ID = 573

        fun enqueueWork(context: Context, intent: Intent) {
            enqueueWork(context, GeofenceTransitionService::class.java, JOB_ID, intent)
        }
    }
}
