package com.placealertme.sample

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.registerReceiver
import com.placealertme.core.GeoTrackingManager
import com.placealertme.services.LocationTrackingService

class SampleActivity : AppCompatActivity() {

    private val trackingManager by lazy {
        GeoTrackingManager.getInstance(this)
    }

    private lateinit var statusTextView: TextView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var addZoneButton: Button

    private var isTracking = false
    private val zoneStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val isInside = intent.getBooleanExtra("isInside", false)
            val distance = intent.getDoubleExtra("distance", 0.0)
            val nextInterval = intent.getLongExtra("nextInterval", 10000L)

            val status = buildString {
                append("Status: ${if (isInside) "INSIDE ZONE" else "OUTSIDE ZONE"}\n")
                append("Distance: %.2f m\n".format(distance))
                append("Next Update: ${nextInterval}ms\n")
            }

            statusTextView.text = status
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_sample)

        initializeViews()
        checkAndRequestPermissions()
        registerZoneStatusReceiver()
    }

    private fun initializeViews() {
        statusTextView = findViewById(R.id.statusTextView)
        startButton = findViewById(R.id.startButton).apply {
            setOnClickListener { onStartTracking() }
        }
        stopButton = findViewById(R.id.stopButton).apply {
            setOnClickListener { onStopTracking() }
        }
        addZoneButton = findViewById(R.id.addZoneButton).apply {
            setOnClickListener { onAddZone() }
        }

        updateUI()
    }

    private fun checkAndRequestPermissions() {
        val requiredPermissions = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACTIVITY_RECOGNITION
        )

        // Add background location for Android 10+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            requiredPermissions.plusElement(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        val missingPermissions = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                missingPermissions.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    private fun registerZoneStatusReceiver() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                zoneStatusReceiver,
                IntentFilter(LocationTrackingService.ACTION_ZONE_STATUS_CHANGED),
                ContextCompat.RECEIVER_EXPORTED
            )
        } else {
            registerReceiver(
                zoneStatusReceiver,
                IntentFilter(LocationTrackingService.ACTION_ZONE_STATUS_CHANGED)
            )
        }
    }

    private fun onStartTracking() {
        if (!isTracking) {
            trackingManager.startTracking()
            isTracking = true
            statusTextView.text = "Tracking started..."
            updateUI()
        }
    }

    private fun onStopTracking() {
        if (isTracking) {
            trackingManager.stopTracking()
            isTracking = false
            statusTextView.text = "Tracking stopped"
            updateUI()
        }
    }

    private fun onAddZone() {
        // Example: Add a geofence zone around San Francisco
        trackingManager.addGeofenceZone(
            latitude = 37.7749,
            longitude = -122.4194,
            radiusMeters = 5000.0  // 5 km radius
        )

        statusTextView.text = "Added zone: San Francisco (5km radius)"
    }

    private fun updateUI() {
        startButton.isEnabled = !isTracking
        stopButton.isEnabled = isTracking
        addZoneButton.isEnabled = isTracking
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(zoneStatusReceiver)
        trackingManager.stopTracking()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                statusTextView.text = "Permissions granted"
            } else {
                statusTextView.text = "Permissions denied - app may not function properly"
            }
        }
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 100
    }
}
