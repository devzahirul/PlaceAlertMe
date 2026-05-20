package com.placealertme.geofence

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.Priority
import com.google.android.gms.location.LocationServices
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

internal class LocationTrackingService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private var locationCallback: LocationCallback? = null
    private var currentIntervalMs = 10000L

    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())

        when (intent?.action) {
            "com.placealertme.ACTION_PAUSE" -> pauseTracking()
            "com.placealertme.ACTION_RESUME" -> resumeTracking()
            else -> startLocationUpdates()
        }

        return START_STICKY
    }

    private fun startLocationUpdates() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                for (location in locationResult.locations) {
                    handleLocationUpdate(
                        location.latitude,
                        location.longitude,
                        location.speed
                    )
                }
            }
        }

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            currentIntervalMs
        )
            .setMinUpdateDistanceMeters(5f)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun handleLocationUpdate(latitude: Double, longitude: Double, speedMps: Float) {
        serviceScope.launch {
            val response = GeoEngineJNI.processLocationWrapped(
                latitude,
                longitude,
                speedMps.toDouble()
            )

            currentIntervalMs = response.nextIntervalMs

            // Update location request with new interval
            updateLocationRequest()

            // Notify listeners about zone status
            val intent = Intent(GeoTracker.ACTION_ZONE_STATUS_CHANGED).apply {
                putExtra(GeoTracker.EXTRA_IS_INSIDE, response.isInsideZone)
                putExtra(GeoTracker.EXTRA_DISTANCE, response.distanceMeters)
                putExtra(GeoTracker.EXTRA_NEXT_INTERVAL, response.nextIntervalMs)
                putExtra(GeoTracker.EXTRA_LATITUDE, latitude)
                putExtra(GeoTracker.EXTRA_LONGITUDE, longitude)
            }
            sendBroadcast(intent)
        }
    }

    private fun updateLocationRequest() {
        if (locationCallback != null) {
            try {
                fusedLocationClient.removeLocationUpdates(locationCallback!!)
            } catch (e: SecurityException) {
                e.printStackTrace()
            }

            val locationRequest = LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                currentIntervalMs
            )
                .setMinUpdateDistanceMeters(5f)
                .build()

            try {
                fusedLocationClient.requestLocationUpdates(
                    locationRequest,
                    locationCallback!!,
                    Looper.getMainLooper()
                )
            } catch (e: SecurityException) {
                e.printStackTrace()
            }
        }
    }

    fun pauseTracking() {
        try {
            locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    fun resumeTracking() {
        startLocationUpdates()
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Tracking Active")
            .setContentText("PlaceAlertMe is tracking your location")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Location Tracking"
            val descriptionText = "Notifications for location tracking service"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        try {
            locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID = "geo_tracking_channel"
        const val NOTIFICATION_ID = 42
    }
}
