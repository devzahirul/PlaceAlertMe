package com.placealertme.geofence

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(entities = [GeofenceZoneEntity::class, PlaceVisitEntity::class], version = 3, exportSchema = false)
abstract class GeofenceDatabase : RoomDatabase() {
    abstract fun zoneDao(): GeofenceZoneDao
    abstract fun visitDao(): PlaceVisitDao

    companion object {
        @Volatile private var INSTANCE: GeofenceDatabase? = null

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS `place_visits` (
                        `visitId` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `zoneId` TEXT NOT NULL,
                        `zoneName` TEXT NOT NULL,
                        `arrivalTimestampMs` INTEGER NOT NULL,
                        `departureTimestampMs` INTEGER NOT NULL DEFAULT -1,
                        `arrivalLatitude` REAL NOT NULL,
                        `arrivalLongitude` REAL NOT NULL,
                        `arrivalSpeedMps` REAL NOT NULL
                    )
                """)
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE place_visits ADD COLUMN `arrivalActivityType` TEXT NOT NULL DEFAULT 'unknown'")
            }
        }

        fun getInstance(context: Context): GeofenceDatabase =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: Room.databaseBuilder(
                    context.applicationContext,
                    GeofenceDatabase::class.java,
                    "placealertme_zones.db"
                ).addMigrations(MIGRATION_1_2, MIGRATION_2_3).build().also { INSTANCE = it }
            }
    }
}
