package com.placealertme.core

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import com.placealertme.services.LocationTrackingService

class ActivityRecognitionHelper(private val context: Context) {

    private val activityRecognitionClient = ActivityRecognition.getClient(context)
    private var isTracking = false

    fun startActivityRecognition() {
        if (isTracking) return

        val intent = Intent(context, ActivityRecognitionReceiver::class.java)
        val pendingIntent = android.app.PendingIntent.getService(
            context, ACTIVITY_RECOGNITION_REQUEST_CODE, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE
        )

        try {
            activityRecognitionClient.requestActivityUpdates(
                ACTIVITY_UPDATE_INTERVAL_MS,
                pendingIntent
            ).addOnSuccessListener {
                isTracking = true
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    fun stopActivityRecognition() {
        if (!isTracking) return

        val intent = Intent(context, ActivityRecognitionReceiver::class.java)
        val pendingIntent = android.app.PendingIntent.getService(
            context, ACTIVITY_RECOGNITION_REQUEST_CODE, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE
        )

        try {
            activityRecognitionClient.removeActivityUpdates(pendingIntent)
                .addOnSuccessListener {
                    isTracking = false
                }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    companion object {
        const val ACTIVITY_RECOGNITION_REQUEST_CODE = 100
        const val ACTIVITY_UPDATE_INTERVAL_MS = 10000L

        fun activityTypeString(detectedActivity: DetectedActivity?): String {
            if (detectedActivity == null) return "unknown"
            return when (detectedActivity.type) {
                DetectedActivity.IN_VEHICLE -> "auto"
                DetectedActivity.ON_BICYCLE -> "cycling"
                DetectedActivity.ON_FOOT -> {
                    if (detectedActivity.confidence >= 80) "walking" else "unknown"
                }
                DetectedActivity.RUNNING -> "running"
                DetectedActivity.STILL -> "stationary"
                DetectedActivity.TILTING -> "unknown"
                DetectedActivity.WALKING -> "walking"
                else -> "unknown"
            }
        }
    }
}

class ActivityRecognitionReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        if (ActivityRecognitionResult.hasResult(intent)) {
            val result = ActivityRecognitionResult.extractResult(intent)
            val mostProbableActivity = result?.getMostProbableActivity()

            currentActivityType = ActivityRecognitionHelper.activityTypeString(mostProbableActivity)
            val isStill = mostProbableActivity?.type == DetectedActivity.STILL

            val trackingIntent = Intent(context, LocationTrackingService::class.java).apply {
                action = if (isStill) ACTION_PAUSE_TRACKING else ACTION_RESUME_TRACKING
            }

            ContextCompat.startForegroundService(context, trackingIntent)
        }
    }

    companion object {
        const val ACTION_PAUSE_TRACKING = "com.placealertme.ACTION_PAUSE_TRACKING"
        const val ACTION_RESUME_TRACKING = "com.placealertme.ACTION_RESUME_TRACKING"

        @Volatile
        var currentActivityType: String = "unknown"
    }
}
