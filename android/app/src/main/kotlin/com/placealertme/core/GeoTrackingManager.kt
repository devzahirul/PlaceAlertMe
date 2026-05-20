package com.placealertme.core

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.placealertme.services.LocationTrackingService

class GeoTrackingManager(private val context: Context) {

    private val activityRecognitionHelper = ActivityRecognitionHelper(context)
    private var isTrackingActive = false

    fun startTracking() {
        if (isTrackingActive) return

        val intent = Intent(context, LocationTrackingService::class.java)
        ContextCompat.startForegroundService(context, intent)

        activityRecognitionHelper.startActivityRecognition()
        isTrackingActive = true
    }

    fun stopTracking() {
        if (!isTrackingActive) return

        val intent = Intent(context, LocationTrackingService::class.java)
        context.stopService(intent)

        activityRecognitionHelper.stopActivityRecognition()
        isTrackingActive = false
    }

    fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        getLocationTrackingService()?.addGeofenceZone(latitude, longitude, radiusMeters)
    }

    fun clearGeofenceZones() {
        getLocationTrackingService()?.clearGeofenceZones()
    }

    fun pauseTracking() {
        getLocationTrackingService()?.pauseTracking()
    }

    fun resumeTracking() {
        getLocationTrackingService()?.resumeTracking()
    }

    private fun getLocationTrackingService(): LocationTrackingService? {
        return null
    }

    companion object {
        @Volatile
        private var instance: GeoTrackingManager? = null

        fun getInstance(context: Context): GeoTrackingManager {
            return instance ?: synchronized(this) {
                instance ?: GeoTrackingManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
