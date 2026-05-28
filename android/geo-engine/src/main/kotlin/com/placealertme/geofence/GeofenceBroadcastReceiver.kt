package com.placealertme.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives native GeofencingClient transitions via a getBroadcast PendingIntent
 * and forwards them to [GeofenceTransitionService] through enqueueWork.
 *
 * A BroadcastReceiver can be triggered while the app is terminated, whereas a
 * direct background startService call is blocked on Android O+. enqueueWork
 * schedules the work on the JobScheduler so the transition is processed reliably.
 */
internal class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        GeofenceTransitionService.enqueueWork(context, intent)
    }
}
