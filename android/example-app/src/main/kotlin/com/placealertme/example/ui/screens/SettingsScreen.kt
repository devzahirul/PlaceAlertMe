package com.placealertme.example.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController

@Composable
fun SettingsScreen(navController: NavHostController) {
    var notificationsEnabled by remember { mutableStateOf(true) }
    var batteryOptimization by remember { mutableStateOf(true) }
    var backgroundTracking by remember { mutableStateOf(true) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Text(
                    "Tracking Settings",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            item {
                SettingSwitchItem(
                    title = "Notifications",
                    description = "Get alerts when entering/leaving zones",
                    checked = notificationsEnabled,
                    onCheckedChange = { notificationsEnabled = it }
                )
            }

            item {
                SettingSwitchItem(
                    title = "Battery Optimization",
                    description = "Reduce battery usage with adaptive tracking",
                    checked = batteryOptimization,
                    onCheckedChange = { batteryOptimization = it }
                )
            }

            item {
                SettingSwitchItem(
                    title = "Background Tracking",
                    description = "Track location when app is in background",
                    checked = backgroundTracking,
                    onCheckedChange = { backgroundTracking = it }
                )
            }

            item {
                Divider()
            }

            item {
                Text(
                    "About",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            item {
                SettingInfoItem(
                    title = "Version",
                    value = "1.0.0"
                )
            }

            item {
                SettingInfoItem(
                    title = "Library Version",
                    value = "1.0.0"
                )
            }

            item {
                SettingInfoItem(
                    title = "Build Type",
                    value = "Release"
                )
            }

            item {
                Divider()
            }

            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "PlaceAlertMe",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Custom Geofencing Engine",
                        fontSize = 12.sp,
                        color = androidx.compose.ui.graphics.Color.Gray
                    )
                    Text(
                        "© 2024 All Rights Reserved",
                        fontSize = 11.sp,
                        color = androidx.compose.ui.graphics.Color.Gray,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun SettingSwitchItem(
    title: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
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
                    title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    description,
                    fontSize = 12.sp,
                    color = androidx.compose.ui.graphics.Color.Gray,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }

            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange
            )
        }
    }
}

@Composable
fun SettingInfoItem(
    title: String,
    value: String
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                title,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )

            Text(
                value,
                fontSize = 14.sp,
                color = androidx.compose.ui.graphics.Color.Gray
            )
        }
    }
}
