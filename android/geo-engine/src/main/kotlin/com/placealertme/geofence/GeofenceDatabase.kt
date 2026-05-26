package com.placealertme.geofence

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [GeofenceZoneEntity::class], version = 1, exportSchema = false)
abstract class GeofenceDatabase : RoomDatabase() {
    abstract fun zoneDao(): GeofenceZoneDao

    companion object {
        @Volatile private var INSTANCE: GeofenceDatabase? = null

        fun getInstance(context: Context): GeofenceDatabase =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    GeofenceDatabase::class.java,
                    "placealertme_zones.db"
                ).build().also { INSTANCE = it }
            }
    }
}
