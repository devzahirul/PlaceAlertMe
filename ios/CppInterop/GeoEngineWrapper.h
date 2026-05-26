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

#ifdef __cplusplus
}
#endif

#endif // GEO_ENGINE_WRAPPER_H
