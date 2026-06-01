package com.placealertme.geofence

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object GeofenceNotificationManager {
    private const val CHANNEL_ID   = "placealertme_geofence"
    private const val CHANNEL_NAME = "Place Alerts"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Notifications when you arrive at or leave a place"
            }
            context.getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    fun notifyEnter(context: Context, zoneId: String, zoneName: String) {
        send(context, zoneId.hashCode() xor 1,
            title = "Arrived at $zoneName",
            text  = "You have arrived at $zoneName")
    }

    fun notifyExit(context: Context, zoneId: String, zoneName: String) {
        send(context, zoneId.hashCode() xor 2,
            title = "Left $zoneName",
            text  = "You have left $zoneName")
    }

    private fun send(context: Context, id: Int, title: String, text: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        nm.notify(id, notification)
    }
}
