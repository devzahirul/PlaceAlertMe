package com.placealertme.geofence

/**
 * JNI bridge to C++ geo_engine
 * Handles direct communication with the native geofencing engine
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
     * @param latitude Zone center latitude (-90 to 90)
     * @param longitude Zone center longitude (-180 to 180)
     * @param radiusMeters Zone radius in meters (> 0)
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
     * Engine response data class
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
