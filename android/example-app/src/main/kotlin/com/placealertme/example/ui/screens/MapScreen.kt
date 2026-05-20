package com.placealertme.example.ui.screens

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavHostController
import com.placealertme.geofence.GeoTracker
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.ItemizedIconOverlay
import org.osmdroid.views.overlay.OverlayItem

@Composable
fun MapScreen(
    navController: NavHostController,
    geoTracker: GeoTracker
) {
    val context = LocalContext.current
    var selectedLocation by remember { mutableStateOf<GeoPoint?>(null) }
    var mapRadius by remember { mutableStateOf(1000.0) }
    var showConfirmDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Select Location") },
                navigationIcon = {
                    IconButton(onClick = { navController.popBackStack() }) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary
                )
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Map View
            AndroidView(
                factory = { ctx ->
                    createMapView(ctx)
                },
                modifier = Modifier.fillMaxSize(),
                update = { mapView ->
                    setupMapView(mapView, selectedLocation) { location ->
                        selectedLocation = location
                    }
                }
            )

            // Bottom Controls
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (selectedLocation != null) {
                    LocationCard(
                        latitude = selectedLocation!!.latitude,
                        longitude = selectedLocation!!.longitude,
                        radius = mapRadius,
                        onRadiusChange = { mapRadius = it }
                    )

                    Row(
                        modifier = Modifier
                            .fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = { selectedLocation = null },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Clear")
                        }

                        Button(
                            onClick = { showConfirmDialog = true },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Filled.Check, contentDescription = "Confirm")
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Create Zone")
                        }
                    }
                } else {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                color = Color(0xFF6C5CE7).copy(alpha = 0.1f),
                                shape = RoundedCornerShape(12.dp)
                            ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(
                            "Tap on the map to select a location for your geofence",
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            color = Color(0xFF6C5CE7),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
            }

            // Zoom Controls
            Column(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FloatingActionButton(
                    onClick = { /* Zoom in */ },
                    modifier = Modifier.size(48.dp),
                    containerColor = MaterialTheme.colorScheme.primary
                ) {
                    Icon(Icons.Filled.Add, contentDescription = "Zoom In")
                }

                FloatingActionButton(
                    onClick = { /* Zoom out */ },
                    modifier = Modifier.size(48.dp),
                    containerColor = MaterialTheme.colorScheme.primary
                ) {
                    Icon(Icons.Filled.Remove, contentDescription = "Zoom Out")
                }
            }
        }
    }

    if (showConfirmDialog && selectedLocation != null) {
        AlertDialog(
            onDismissRequest = { showConfirmDialog = false },
            title = { Text("Create Geofence Zone") },
            text = {
                Text(
                    "Create a geofence zone at this location with a radius of ${mapRadius.toInt()}m?"
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        geoTracker.addGeofenceZone(
                            selectedLocation!!.latitude,
                            selectedLocation!!.longitude,
                            mapRadius
                        )
                        showConfirmDialog = false
                        navController.popBackStack()
                    }
                ) {
                    Text("Create")
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirmDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

fun createMapView(context: Context): MapView {
    Configuration.getInstance().load(context, android.preference.PreferenceManager.getDefaultSharedPreferences(context))

    return MapView(context).apply {
        setTileSource(TileSourceFactory.MAPNIK)
        controller.setZoom(13.0)
        controller.setCenter(GeoPoint(37.7749, -122.4194)) // San Francisco
    }
}

fun setupMapView(
    mapView: MapView,
    selectedLocation: GeoPoint?,
    onLocationSelected: (GeoPoint) -> Unit
) {
    mapView.overlays.clear()

    if (selectedLocation != null) {
        val items = listOf(OverlayItem("Selected", "Tap location", selectedLocation))
        val overlay = ItemizedIconOverlay(items, null, object : ItemizedIconOverlay.OnItemGestureListener<OverlayItem> {
            override fun onItemSingleTapUp(index: Int, item: OverlayItem?): Boolean = true
            override fun onItemLongPress(index: Int, item: OverlayItem?): Boolean = true
        })
        mapView.overlays.add(overlay)
        mapView.controller.setCenter(selectedLocation)
    }

    mapView.setOnTouchListener { v, event ->
        when (event.action) {
            android.view.MotionEvent.ACTION_UP -> {
                if (v is MapView) {
                    val geoPoint = v.projection.fromPixels(event.x.toInt(), event.y.toInt()) as GeoPoint
                    onLocationSelected(geoPoint)
                }
            }
        }
        false
    }

    mapView.invalidate()
}

@Composable
fun LocationCard(
    latitude: Double,
    longitude: Double,
    radius: Double,
    onRadiusChange: (Double) -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                "Selected Location",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Latitude", fontSize = 12.sp, color = Color.Gray)
                    Text(
                        String.format("%.4f", latitude),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Column(modifier = Modifier.weight(1f)) {
                    Text("Longitude", fontSize = 12.sp, color = Color.Gray)
                    Text(
                        String.format("%.4f", longitude),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Divider(modifier = Modifier.padding(vertical = 8.dp))

            Column {
                Text("Radius: ${radius.toInt()}m", fontSize = 12.sp, color = Color.Gray)
                Slider(
                    value = radius.toFloat(),
                    onValueChange = { onRadiusChange(it.toDouble()) },
                    valueRange = 100f..5000f,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("100m", fontSize = 10.sp, color = Color.Gray, modifier = Modifier.weight(1f))
                    Text("5000m", fontSize = 10.sp, color = Color.Gray, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                }
            }
        }
    }
}
