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
     * Add an ID-based geofence zone with trigger flags.
     */
    external fun addZoneWithId(
        zoneId: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        notifyOnEntry: Boolean = true,
        notifyOnExit: Boolean = true
    )

    /**
     * Process a location update
     * @param latitude Current latitude
     * @param longitude Current longitude
     * @param speedMps Speed in meters per second
     * @return LongArray [isInsideZone (0/1), nextIntervalMs, distanceMeters]
     */
    external fun processLocation(latitude: Double, longitude: Double, speedMps: Double): LongArray

    /**
     * Process a location update and return per-zone transition events.
     */
    private external fun processLocationDetailed(
        latitude: Double,
        longitude: Double,
        speedMps: Double
    ): EngineResponse

    /**
     * Update a zone state from a platform-native geofence event. Returns null
     * when C++ dedup or trigger flags suppress the event.
     */
    external fun updateZoneState(zoneId: String, isInside: Boolean): ZoneTransition?

    /**
     * Return nearest zones to a coordinate, sorted by distance.
     */
    external fun nearestZones(latitude: Double, longitude: Double, maxCount: Int): List<NearestZone>

    /**
     * Shared movement threshold check.
     */
    external fun hasMovedSignificantly(
        fromLatitude: Double,
        fromLongitude: Double,
        toLatitude: Double,
        toLongitude: Double,
        thresholdMeters: Double
    ): Boolean

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
        val distanceMeters: Double,
        val transitions: List<ZoneTransition>
    )

    data class ZoneTransition(
        val zoneId: String,
        val isInside: Boolean,
        val distanceMeters: Double,
        val zoneIndex: Int
    )

    data class NearestZone(
        val zoneId: String,
        val zoneIndex: Int,
        val distanceMeters: Double
    )

    /**
     * Wrapper to convert JNI response to data class
     */
    fun processLocationWrapped(latitude: Double, longitude: Double, speedMps: Double): EngineResponse {
        return processLocationDetailed(latitude, longitude, speedMps)
    }
}
