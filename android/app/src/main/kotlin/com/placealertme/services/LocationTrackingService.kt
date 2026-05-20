package com.placealertme.services

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
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.Priority
import com.placealertme.core.GeoEngineJNI
import com.placealertme.core.GeoTrackingManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class LocationTrackingService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var geoTrackingManager: GeoTrackingManager
    private var locationCallback: LocationCallback? = null
    private var currentIntervalMs = 10000L

    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = com.google.android.gms.location.LocationServices
            .getFusedLocationProviderClient(this)
        geoTrackingManager = GeoTrackingManager(this)

        GeoEngineJNI.initializeEngine()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())

        when (intent?.action) {
            "com.placealertme.ACTION_PAUSE_TRACKING" -> pauseTracking()
            "com.placealertme.ACTION_RESUME_TRACKING" -> resumeTracking()
            else -> startLocationUpdates()
        }

        return START_STICKY
    }

    private fun startLocationUpdates() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                for (location in locationResult.locations) {
                    handleLocationUpdate(location.latitude, location.longitude,
                        location.speed)
                }
            }
        }

        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, currentIntervalMs)
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
            val response = GeoEngineJNI.processLocationWrapped(latitude, longitude, speedMps.toDouble())

            currentIntervalMs = response.nextIntervalMs

            // Update location request with new interval
            updateLocationRequest()

            // Notify listeners about zone status
            val intent = Intent(ACTION_ZONE_STATUS_CHANGED).apply {
                putExtra("isInside", response.isInsideZone)
                putExtra("distance", response.distanceMeters)
                putExtra("nextInterval", response.nextIntervalMs)
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

            val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, currentIntervalMs)
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

    fun addGeofenceZone(latitude: Double, longitude: Double, radiusMeters: Double) {
        GeoEngineJNI.addZone(latitude, longitude, radiusMeters)
    }

    fun clearGeofenceZones() {
        GeoEngineJNI.clearZones()
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
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Tracking Active")
            .setContentText("PlaceAlertMe is tracking your location")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
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
        const val ACTION_ZONE_STATUS_CHANGED = "com.placealertme.ZONE_STATUS_CHANGED"
    }
}

// Placeholder for MainActivity to avoid compilation errors
class MainActivity
