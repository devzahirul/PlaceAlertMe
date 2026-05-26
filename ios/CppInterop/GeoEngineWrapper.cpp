#include "GeoEngineWrapper.h"
#include "geo_engine.h"
#include <memory>
#include <cstring>

using namespace geo_engine;

static std::unique_ptr<GeoEngine> g_ios_engine = nullptr;

extern "C" {

void ios_geo_engine_initialize() {
    if (!g_ios_engine) {
        g_ios_engine = std::make_unique<GeoEngine>();
    }
}

void ios_geo_engine_add_zone(const char* id, const char* name,
                              double latitude, double longitude,
                              double radiusMeters) {
    if (!g_ios_engine) return;
    GeofenceZone zone(id ? id : "", name ? name : "", latitude, longitude, radiusMeters);
    g_ios_engine->addZone(zone);
}

void ios_geo_engine_remove_zone(const char* id) {
    if (!g_ios_engine || !id) return;
    g_ios_engine->removeZone(id);
}

struct GeoEngineResult ios_geo_engine_process_location(double latitude, double longitude,
                                                        double speedMps,
                                                        double accuracyMeters,
                                                        long long timestampMs) {
    struct GeoEngineResult result;
    memset(&result, 0, sizeof(result));
    result.nextIntervalMs = 60000;

    if (!g_ios_engine) return result;

    UserLocation loc(latitude, longitude, speedMps, accuracyMeters, (int64_t)timestampMs);
    EngineResponse response = g_ios_engine->processLocation(loc);

    result.isInsideAnyZone        = response.isInsideAnyZone;
    result.nextIntervalMs         = response.nextIntervalMs;
    result.distanceToNearestMeters = response.distanceToNearestMeters;

    int count = (int)response.transitions.size();
    if (count > 20) count = 20;
    result.transitionCount = count;

    for (int i = 0; i < count; ++i) {
        const auto& t = response.transitions[i];
        strncpy(result.transitions[i].zoneId,   t.zoneId.c_str(),   63);
        strncpy(result.transitions[i].zoneName, t.zoneName.c_str(), 127);
        result.transitions[i].zoneId[63]    = '\0';
        result.transitions[i].zoneName[127] = '\0';
        result.transitions[i].type          = (t.type == TransitionType::ENTER) ? 0 : 1;
        result.transitions[i].distanceMeters = t.distanceMeters;
        result.transitions[i].timestampMs   = (long long)t.timestampMs;
    }

    return result;
}

void ios_geo_engine_clear_zones() {
    if (g_ios_engine) g_ios_engine->clearZones();
}

int ios_geo_engine_get_zone_count() {
    if (g_ios_engine) return (int)g_ios_engine->getZoneCount();
    return 0;
}

}  // extern "C"
