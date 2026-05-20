package com.placealertme.example

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.placealertme.example.ui.screens.HomeScreen
import com.placealertme.example.ui.screens.MapScreen
import com.placealertme.example.ui.screens.SettingsScreen
import com.placealertme.example.ui.theme.PlaceAlertMeTheme
import com.placealertme.geofence.GeoTracker
import android.content.pm.PackageManager

class MainActivity : ComponentActivity() {

    private lateinit var geoTracker: GeoTracker
    private var broadcastReceiver: BroadcastReceiver? = null

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        permissions.forEach { (permission, isGranted) ->
            if (isGranted) {
                if (permission == Manifest.permission.ACCESS_FINE_LOCATION) {
                    startTracking()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        geoTracker = GeoTracker(this)

        setContent {
            PlaceAlertMeTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val navController = rememberNavController()
                    AppNavigation(navController, geoTracker, ::startTracking, ::stopTracking)
                }
            }
        }

        setupBroadcastReceiver()
        requestPermissions()
    }

    private fun requestPermissions() {
        val requiredPermissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACTIVITY_RECOGNITION
        )

        val missingPermissions = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missingPermissions.isNotEmpty()) {
            permissionLauncher.launch(missingPermissions.toTypedArray())
        } else {
            startTracking()
        }
    }

    private fun startTracking() {
        try {
            geoTracker.startTracking()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopTracking() {
        geoTracker.stopTracking()
    }

    private fun setupBroadcastReceiver() {
        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                // Handle zone status changes if needed
            }
        }

        val filter = IntentFilter("com.placealertme.ZONE_STATUS_CHANGED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(broadcastReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(broadcastReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        broadcastReceiver?.let { unregisterReceiver(it) }
        stopTracking()
    }
}

@Composable
fun AppNavigation(
    navController: NavHostController,
    geoTracker: GeoTracker,
    onStartTracking: () -> Unit,
    onStopTracking: () -> Unit
) {
    NavHost(navController = navController, startDestination = "home") {
        composable("home") {
            HomeScreen(
                navController = navController,
                geoTracker = geoTracker,
                onStartTracking = onStartTracking,
                onStopTracking = onStopTracking
            )
        }

        composable("map") {
            MapScreen(
                navController = navController,
                geoTracker = geoTracker
            )
        }

        composable("settings") {
            SettingsScreen(navController = navController)
        }
    }
}
