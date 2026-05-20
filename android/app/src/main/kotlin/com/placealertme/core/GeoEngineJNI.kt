package com.placealertme.core

/**
 * JNI bridge to C++ geo_engine
 */
object GeoEngineJNI {
    init {
        System.loadLibrary("geo_engine_jni")
    }

    /**
     * Initialize the geofencing engine
     */
    external fun initializeEngine()

    /**
     * Add a geofence zone
     * @param latitude Zone center latitude
     * @param longitude Zone center longitude
     * @param radiusMeters Zone radius in meters
     */
    external fun addZone(latitude: Double, longitude: Double, radiusMeters: Double)

    /**
     * Process a location update
     * @param latitude Current latitude
     * @param longitude Current longitude
     * @param speedMps Speed in meters per second
     * @return LongArray [isInsideZone (0/1), nextIntervalMs, distanceMeters]
     */
    external fun processLocation(latitude: Double, longitude: Double, speedMps: Double): LongArray

    /**
     * Clear all zones
     */
    external fun clearZones()

    /**
     * Get count of managed zones
     */
    external fun getZoneCount(): Int

    /**
     * Data class for engine response
     */
    data class EngineResponse(
        val isInsideZone: Boolean,
        val nextIntervalMs: Long,
        val distanceMeters: Double
    )

    /**
     * Wrapper to convert JNI response to data class
     */
    fun processLocationWrapped(latitude: Double, longitude: Double, speedMps: Double): EngineResponse {
        val response = processLocation(latitude, longitude, speedMps)
        return EngineResponse(
            isInsideZone = response[0] != 0L,
            nextIntervalMs = response[1],
            distanceMeters = response[2].toDouble()
        )
    }
}
