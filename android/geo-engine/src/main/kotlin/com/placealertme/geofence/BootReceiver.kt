package com.placealertme.geofence

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        GeoEngineJNI.initializeEngine()
        CoroutineScope(Dispatchers.IO).launch {
            val zones = GeofenceDatabase.getInstance(context).zoneDao().getAll()
            zones.forEach { z ->
                GeoEngineJNI.addZone(z.id, z.name, z.latitude, z.longitude, z.radiusMeters)
                GeofenceNativeManager.addZone(context, z.id, z.latitude, z.longitude, z.radiusMeters)
            }
        }
    }
}
