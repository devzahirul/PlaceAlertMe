package com.placealertme.example.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import com.placealertme.geofence.GeoTracker

@Composable
fun HomeScreen(
    navController: NavHostController,
    geoTracker: GeoTracker,
    onStartTracking: () -> Unit,
    onStopTracking: () -> Unit
) {
    var isTrackingActive by remember { mutableStateOf(false) }
    var zoneCount by remember { mutableStateOf(0) }
    var showAddZoneDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("PlaceAlertMe") },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddZoneDialog = true },
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Add Zone")
            }
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    icon = { Icon(Icons.Filled.Home, contentDescription = "Home") },
                    label = { Text("Home") },
                    selected = true,
                    onClick = {}
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Filled.LocationOn, contentDescription = "Map") },
                    label = { Text("Map") },
                    selected = false,
                    onClick = { navController.navigate("map") }
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Filled.Settings, contentDescription = "Settings") },
                    label = { Text("Settings") },
                    selected = false,
                    onClick = { navController.navigate("settings") }
                )
            }
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                TrackingStatusCard(
                    isActive = isTrackingActive,
                    onToggle = { newState ->
                        isTrackingActive = newState
                        if (newState) {
                            onStartTracking()
                        } else {
                            onStopTracking()
                        }
                    }
                )
            }

            item {
                ZoneStatsCard(zoneCount = zoneCount)
            }

            item {
                QuickActionsCard(
                    onMapClick = { navController.navigate("map") },
                    onAddZoneClick = { showAddZoneDialog = true }
                )
            }

            item {
                Text(
                    "Your Zones",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 16.dp)
                )
            }

            item {
                if (zoneCount == 0) {
                    NoZonesPlaceholder { showAddZoneDialog = true }
                } else {
                    Text("Zones added: $zoneCount")
                }
            }
        }
    }

    if (showAddZoneDialog) {
        AddZoneDialog(
            onDismiss = { showAddZoneDialog = false },
            onConfirm = { latitude, longitude, radius ->
                geoTracker.addGeofenceZone(latitude, longitude, radius)
                zoneCount = geoTracker.getZoneCount()
                showAddZoneDialog = false
            },
            onMapClick = {
                showAddZoneDialog = false
                navController.navigate("map")
            }
        )
    }
}

@Composable
fun TrackingStatusCard(
    isActive: Boolean,
    onToggle: (Boolean) -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (isActive) Color(0xFF6C5CE7) else Color(0xFFE8E8E8)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 16.dp)
            ) {
                Text(
                    "Tracking Status",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (isActive) Color.White else Color.Black
                )
                Text(
                    if (isActive) "Active" else "Inactive",
                    fontSize = 14.sp,
                    color = if (isActive) Color.White.copy(alpha = 0.8f) else Color.Gray
                )
            }

            Switch(
                checked = isActive,
                onCheckedChange = onToggle
            )
        }
    }
}

@Composable
fun ZoneStatsCard(zoneCount: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Card(
            modifier = Modifier
                .weight(1f)
                .height(100.dp),
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF00B4D8).copy(alpha = 0.1f)
            )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    zoneCount.toString(),
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF00B4D8)
                )
                Text("Zones", fontSize = 12.sp, color = Color.Gray)
            }
        }

        Card(
            modifier = Modifier
                .weight(1f)
                .height(100.dp),
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF48DBFB).copy(alpha = 0.1f)
            )
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    "Ready",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color(0xFF48DBFB)
                )
                Text("Status", fontSize = 12.sp, color = Color.Gray)
            }
        }
    }
}

@Composable
fun QuickActionsCard(
    onMapClick: () -> Unit,
    onAddZoneClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            ActionButton(
                icon = Icons.Filled.LocationOn,
                label = "Open Map",
                modifier = Modifier.weight(1f),
                onClick = onMapClick
            )
            ActionButton(
                icon = Icons.Filled.Add,
                label = "Add Zone",
                modifier = Modifier.weight(1f),
                onClick = onAddZoneClick
            )
        }
    }
}

@Composable
fun ActionButton(
    icon: androidx.compose.material.icons.Icons,
    label: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.height(48.dp),
        shape = RoundedCornerShape(8.dp)
    ) {
        Icon(icon, contentDescription = label, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.width(8.dp))
        Text(label, fontSize = 12.sp)
    }
}

@Composable
fun NoZonesPlaceholder(onAddClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFFF5F5F5)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                Icons.Filled.LocationOn,
                contentDescription = "No zones",
                modifier = Modifier
                    .size(48.dp)
                    .padding(bottom = 16.dp),
                tint = Color.Gray
            )
            Text(
                "No zones yet",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color.Gray
            )
            Text(
                "Create your first geofence zone",
                fontSize = 12.sp,
                color = Color.Gray,
                modifier = Modifier.padding(top = 4.dp)
            )
            Button(
                onClick = onAddClick,
                modifier = Modifier.padding(top = 16.dp)
            ) {
                Text("Add Zone")
            }
        }
    }
}

@Composable
fun AddZoneDialog(
    onDismiss: () -> Unit,
    onConfirm: (Double, Double, Double) -> Unit,
    onMapClick: () -> Unit
) {
    var latitude by remember { mutableStateOf("37.7749") }
    var longitude by remember { mutableStateOf("-122.4194") }
    var radius by remember { mutableStateOf("1000") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Geofence Zone") },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                OutlinedTextField(
                    value = latitude,
                    onValueChange = { latitude = it },
                    label = { Text("Latitude") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = longitude,
                    onValueChange = { longitude = it },
                    label = { Text("Longitude") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = radius,
                    onValueChange = { radius = it },
                    label = { Text("Radius (meters)") },
                    modifier = Modifier.fillMaxWidth()
                )
                Button(
                    onClick = onMapClick,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(Icons.Filled.LocationOn, contentDescription = "Map", modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Pick Location on Map")
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    try {
                        onConfirm(
                            latitude.toDouble(),
                            longitude.toDouble(),
                            radius.toDouble()
                        )
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            ) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
