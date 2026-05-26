package com.placealertme.geofence

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface GeofenceZoneDao {
    @Query("SELECT * FROM geofence_zones")
    fun getAll(): List<GeofenceZoneEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun insert(zone: GeofenceZoneEntity)

    @Query("DELETE FROM geofence_zones WHERE id = :id")
    fun deleteById(id: String)

    @Query("DELETE FROM geofence_zones")
    fun deleteAll()
}
