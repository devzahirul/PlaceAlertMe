#ifndef GEO_ENGINE_WRAPPER_H
#define GEO_ENGINE_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Result structure for C interface
 */
struct GeoEngineResult {
    bool isInsideZone;
    long long nextIntervalMs;
    double distanceMeters;
};

/**
 * Initialize the geofencing engine
 */
void ios_geo_engine_initialize(void);

/**
 * Add a geofence zone
 * @param latitude Zone center latitude
 * @param longitude Zone center longitude
 * @param radiusMeters Zone radius in meters
 */
void ios_geo_engine_add_zone(double latitude, double longitude, double radiusMeters);

/**
 * Process location update
 * @param latitude Current latitude
 * @param longitude Current longitude
 * @param speedMps Speed in meters per second
 * @return GeoEngineResult with zone status and recommendations
 */
struct GeoEngineResult ios_geo_engine_process_location(double latitude, double longitude, double speedMps);

/**
 * Clear all zones
 */
void ios_geo_engine_clear_zones(void);

/**
 * Get count of managed zones
 */
int ios_geo_engine_get_zone_count(void);

#ifdef __cplusplus
}
#endif

#endif // GEO_ENGINE_WRAPPER_H
