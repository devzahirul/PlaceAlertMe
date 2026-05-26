package com.placealertme.geofence

import androidx.room.*

@Dao
interface PlaceVisitDao {
    @Insert
    suspend fun insert(visit: PlaceVisitEntity): Long

    @Query("UPDATE place_visits SET departureTimestampMs = :departureMs WHERE zoneId = :zoneId AND departureTimestampMs = -1")
    suspend fun closeVisit(zoneId: String, departureMs: Long)

    @Query("SELECT * FROM place_visits WHERE departureTimestampMs = -1")
    suspend fun getActiveVisits(): List<PlaceVisitEntity>

    @Query("SELECT * FROM place_visits WHERE zoneId = :zoneId ORDER BY arrivalTimestampMs DESC LIMIT :limit")
    suspend fun getVisitHistory(zoneId: String, limit: Int = 50): List<PlaceVisitEntity>

    @Query("SELECT * FROM place_visits ORDER BY arrivalTimestampMs DESC LIMIT :limit")
    suspend fun getAllVisitHistory(limit: Int = 100): List<PlaceVisitEntity>

    @Query("DELETE FROM place_visits WHERE arrivalTimestampMs < :beforeMs")
    suspend fun pruneOlderThan(beforeMs: Long)
}
