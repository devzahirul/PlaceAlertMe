#ifndef GEO_ENGINE_WRAPPER_H
#define GEO_ENGINE_WRAPPER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Per-zone transition (fixed array avoids heap alloc across C/C++ boundary;
// 20-zone limit also matches iOS CLCircularRegion maximum)
struct GeoEngineTransition {
    char      zoneId[64];
    char      zoneName[128];
    int       type;           // 0 = ENTER, 1 = EXIT
    double    distanceMeters;
    long long timestampMs;
};

struct GeoEngineResult {
    bool      isInsideAnyZone;
    long long nextIntervalMs;
    double    distanceToNearestMeters;
    int       transitionCount;
    struct    GeoEngineTransition transitions[20];
};

void                   ios_geo_engine_initialize(void);
void                   ios_geo_engine_add_zone(const char* id, const char* name,
                                                double latitude, double longitude,
                                                double radiusMeters);
void                   ios_geo_engine_remove_zone(const char* id);
struct GeoEngineResult ios_geo_engine_process_location(double latitude, double longitude,
                                                        double speedMps,
                                                        double accuracyMeters,
                                                        long long timestampMs);
void                   ios_geo_engine_clear_zones(void);
int                    ios_geo_engine_get_zone_count(void);

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
