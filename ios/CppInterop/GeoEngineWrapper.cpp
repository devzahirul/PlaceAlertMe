#include "geo_engine.h"
#include <memory>
#include <vector>

using namespace geo_engine;

// Global reference to GeoEngine instance
static std::unique_ptr<GeoEngine> g_ios_engine = nullptr;

// Swift-callable C interface
extern \"C\" {

/**
 * Initialize the geofencing engine (C interface for Swift)
 */
void ios_geo_engine_initialize() {
    if (!g_ios_engine) {
        g_ios_engine = std::make_unique<GeoEngine>();
    }
}

/**
 * Add a geofence zone (C interface for Swift)
 */
void ios_geo_engine_add_zone(double latitude, double longitude, double radiusMeters) {
    if (g_ios_engine) {
        GeofenceZone zone(latitude, longitude, radiusMeters);
        g_ios_engine->addZone(zone);
    }
}

/**
 * Process location update (C interface for Swift)
 * Returns a struct with results
 */
struct GeoEngineResult {
    bool isInsideZone;
    long long nextIntervalMs;
    double distanceMeters;
};

GeoEngineResult ios_geo_engine_process_location(double latitude, double longitude, double speedMps) {
    GeoEngineResult result = {false, 60000, 0.0};

    if (g_ios_engine) {
        UserLocation location(latitude, longitude, speedMps);
        EngineResponse response = g_ios_engine->processLocation(location);

        result.isInsideZone = response.isInsideZone;
        result.nextIntervalMs = response.nextIntervalMs;
        result.distanceMeters = response.distanceMeters;
    }

    return result;
}

/**
 * Clear all zones (C interface for Swift)
 */
void ios_geo_engine_clear_zones() {
    if (g_ios_engine) {
        g_ios_engine->clearZones();
    }
}

/**
 * Get zone count (C interface for Swift)
 */
int ios_geo_engine_get_zone_count() {
    if (g_ios_engine) {
        return (int)g_ios_engine->getZoneCount();
    }
    return 0;
}

}
