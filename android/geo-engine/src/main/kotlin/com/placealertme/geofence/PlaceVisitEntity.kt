package com.placealertme.geofence

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "place_visits")
data class PlaceVisitEntity(
    @PrimaryKey(autoGenerate = true)
    val visitId: Long = 0,
    val zoneId: String,
    val zoneName: String,
    val arrivalTimestampMs: Long,
    val departureTimestampMs: Long = -1L,   // -1 = still inside
    val arrivalLatitude: Double,
    val arrivalLongitude: Double,
    val arrivalSpeedMps: Double,
    val arrivalActivityType: String = "unknown"
) {
    val isActive: Boolean get() = departureTimestampMs == -1L
    val durationMs: Long get() = if (isActive) -1L else departureTimestampMs - arrivalTimestampMs
}
