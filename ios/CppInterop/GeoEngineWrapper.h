#ifndef GEO_ENGINE_WRAPPER_H
#define GEO_ENGINE_WRAPPER_H

#include <stdbool.h>

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
    int transitionCount;
};

/**
 * Per-zone transition returned by the C++ decision layer.
 * zoneId points to wrapper-owned storage that is valid until the next
 * ios_geo_engine_* call on the same thread. Swift copies it immediately.
 */
struct GeoEngineTransition {
    const char *zoneId;
    bool isInside;
    int zoneIndex;
    double distanceMeters;
};

/**
 * Nearest-zone result returned by the C++ decision layer.
 */
struct GeoEngineNearestZone {
    const char *zoneId;
    int zoneIndex;
    double distanceMeters;
};

/**
 * Daily navigation-history summary returned by the C++ history layer.
 */
struct NavigationHistoryDaySummaryResult {
    const char *dayKey;
    long long startTimestampMs;
    long long endTimestampMs;
    int pointCount;
    int alertEventCount;
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
 * Add an ID-based geofence zone.
 */
void ios_geo_engine_add_zone_with_id(const char *zoneId,
                                     double latitude,
                                     double longitude,
                                     double radiusMeters,
                                     bool notifyOnEntry,
                                     bool notifyOnExit);

/**
 * Process location update
 * @param latitude Current latitude
 * @param longitude Current longitude
 * @param speedMps Speed in meters per second
 * @return GeoEngineResult with zone status and recommendations
 */
struct GeoEngineResult ios_geo_engine_process_location(double latitude, double longitude, double speedMps);

/**
 * Process location update and copy per-zone transition events into outTransitions.
 * @return GeoEngineResult whose transitionCount is the number copied.
 */
struct GeoEngineResult ios_geo_engine_process_location_with_events(double latitude,
                                                                   double longitude,
                                                                   double speedMps,
                                                                   struct GeoEngineTransition *outTransitions,
                                                                   int maxTransitions);

/**
 * Update a zone state from a platform-native geofence event. Returns true if
 * the event should be surfaced to the host app after C++ dedup + trigger filter.
 */
bool ios_geo_engine_update_zone_state(const char *zoneId,
                                      bool isInside,
                                      struct GeoEngineTransition *outTransition);

/**
 * Return nearest zones to the provided coordinate.
 */
int ios_geo_engine_get_nearest_zones(double latitude,
                                     double longitude,
                                     struct GeoEngineNearestZone *outZones,
                                     int maxZones);

/**
 * Shared movement threshold check.
 */
bool ios_geo_engine_has_moved_significantly(double fromLatitude,
                                            double fromLongitude,
                                            double toLatitude,
                                            double toLongitude,
                                            double thresholdMeters);

/**
 * Clear all zones
 */
void ios_geo_engine_clear_zones(void);

/**
 * Get count of managed zones
 */
int ios_geo_engine_get_zone_count(void);

/**
 * Append a route point to a local day file. Returns true only when the point
 * was accepted by the C++ useful-path filter and written.
 */
bool ios_navigation_history_append_route_point(const char *directory,
                                               const char *dayKey,
                                               long long timestampMs,
                                               double latitude,
                                               double longitude,
                                               double speedMps);

/**
 * Append an alert trigger snapshot to a local day file.
 */
bool ios_navigation_history_append_alert_event(const char *directory,
                                               const char *dayKey,
                                               const char *eventId,
                                               const char *alertId,
                                               const char *task,
                                               const char *place,
                                               const char *address,
                                               const char *eventType,
                                               long long timestampMs,
                                               double latitude,
                                               double longitude);

/**
 * List day summaries in reverse chronological order.
 */
int ios_navigation_history_list_day_summaries(const char *directory,
                                              struct NavigationHistoryDaySummaryResult *outSummaries,
                                              int maxSummaries);

/**
 * Load one day as wrapper-owned JSON. Valid until the next
 * ios_navigation_history_* call on the same thread.
 */
const char *ios_navigation_history_load_day_json(const char *directory,
                                                 const char *dayKey);

/**
 * Remove history files before minimumDayKey. Day keys use YYYY-MM-DD.
 */
int ios_navigation_history_prune_before_day(const char *directory,
                                            const char *minimumDayKey);

#ifdef __cplusplus
}
#endif

#endif // GEO_ENGINE_WRAPPER_H
