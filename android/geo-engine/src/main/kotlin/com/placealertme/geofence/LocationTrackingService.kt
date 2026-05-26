package com.placealertme.geofence

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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

    // Activity scale factor: STILL → 3×, AUTOMOTIVE → 0.5×, else 1×
    @Volatile var activityScaleFactor: Double = 1.0

    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        when (intent?.action) {
            "com.placealertme.ACTION_PAUSE"  -> pauseTracking()
            "com.placealertme.ACTION_RESUME" -> resumeTracking()
            else                             -> startLocationUpdates()
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
                        location.speed,
                        location.accuracy.toDouble(),
                        System.currentTimeMillis()
                    )
                }
            }
        }
        requestUpdatesWithInterval(currentIntervalMs)
    }

    private fun handleLocationUpdate(
        latitude: Double,
        longitude: Double,
        speedMps: Float,
        accuracyMeters: Double,
        timestampMs: Long
    ) {
        serviceScope.launch {
            val response = GeoEngineJNI.processLocationWrapped(
                latitude, longitude, speedMps.toDouble(),
                accuracyMeters, timestampMs
            )

            // Apply activity scale factor to engine's suggested interval
            val scaledInterval = (response.nextIntervalMs * activityScaleFactor)
                .toLong()
                .coerceIn(1000L, 120000L)
            currentIntervalMs = scaledInterval
            updateLocationRequest()

            // Emit per-zone ENTER/EXIT broadcasts
            for (t in response.transitions) {
                val action = if (t.type == "ENTER") GeoTracker.ACTION_ZONE_ENTER
                             else                    GeoTracker.ACTION_ZONE_EXIT
                sendBroadcast(Intent(action).apply {
                    putExtra(GeoTracker.EXTRA_ZONE_ID,   t.zoneId)
                    putExtra(GeoTracker.EXTRA_ZONE_NAME, t.zoneName)
                    putExtra(GeoTracker.EXTRA_DISTANCE,  t.distanceMeters)
                    putExtra(GeoTracker.EXTRA_TIMESTAMP, t.timestampMs)
                })
            }

            // Legacy global broadcast (backwards compat)
            sendBroadcast(Intent(GeoTracker.ACTION_ZONE_STATUS_CHANGED).apply {
                putExtra(GeoTracker.EXTRA_IS_INSIDE,     response.isInsideAnyZone)
                putExtra(GeoTracker.EXTRA_DISTANCE,      response.distanceToNearestMeters)
                putExtra(GeoTracker.EXTRA_NEXT_INTERVAL, response.nextIntervalMs)
                putExtra(GeoTracker.EXTRA_LATITUDE,      latitude)
                putExtra(GeoTracker.EXTRA_LONGITUDE,     longitude)
            })
        }
    }

    private fun updateLocationRequest() {
        locationCallback?.let { cb ->
            try { fusedLocationClient.removeLocationUpdates(cb) } catch (_: SecurityException) {}
            requestUpdatesWithInterval(currentIntervalMs)
        }
    }

    private fun requestUpdatesWithInterval(intervalMs: Long) {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateDistanceMeters(5f)
            .build()
        try {
            fusedLocationClient.requestLocationUpdates(
                request, locationCallback!!, Looper.getMainLooper()
            )
        } catch (_: SecurityException) {}
    }

    fun pauseTracking() {
        try { locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) } }
        catch (_: SecurityException) {}
    }

    fun resumeTracking() { startLocationUpdates() }

    private fun createNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location Tracking Active")
            .setContentText("PlaceAlertMe is tracking your location")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Location Tracking", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Notifications for location tracking service" }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        try { locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) } }
        catch (_: SecurityException) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID      = "geo_tracking_channel"
        const val NOTIFICATION_ID = 42
    }
}
