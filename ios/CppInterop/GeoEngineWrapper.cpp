#include "GeoEngineWrapper.h"
#include "geo_engine.h"
#include "history_engine.h"
#include <algorithm>
#include <memory>
#include <string>
#include <vector>

using namespace geo_engine;

// Global reference to GeoEngine instance
static std::unique_ptr<GeoEngine> g_ios_engine = nullptr;
static NavigationHistoryEngine g_ios_history_engine;
static thread_local std::vector<std::string> g_ios_transition_ids;
static thread_local std::vector<std::string> g_ios_nearest_ids;
static thread_local std::string g_ios_single_transition_id;
static thread_local std::vector<std::string> g_ios_history_day_keys;
static thread_local std::string g_ios_history_json;

static GeoEngineResult make_result(const EngineResponse& response, int transitionCount) {
    GeoEngineResult result;
    result.isInsideZone = response.isInsideZone;
    result.nextIntervalMs = response.nextIntervalMs;
    result.distanceMeters = response.distanceMeters;
    result.transitionCount = transitionCount;
    return result;
}

static void copy_transition(const ZoneTransition& source, GeoEngineTransition& target) {
    target.isInside = source.isInside;
    target.zoneIndex = source.zoneIndex;
    target.distanceMeters = source.distanceMeters;
}

// Swift-callable C interface
extern "C" {

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

void ios_geo_engine_add_zone_with_id(const char *zoneId,
                                     double latitude,
                                     double longitude,
                                     double radiusMeters,
                                     bool notifyOnEntry,
                                     bool notifyOnExit) {
    if (g_ios_engine) {
        GeofenceZone zone(
            zoneId ? std::string(zoneId) : std::string(),
            latitude,
            longitude,
            radiusMeters,
            notifyOnEntry,
            notifyOnExit
        );
        g_ios_engine->addZone(zone);
    }
}

/**
 * Process location update (C interface for Swift)
 * Returns a struct with results
 */
GeoEngineResult ios_geo_engine_process_location(double latitude, double longitude, double speedMps) {
    GeoEngineResult result = {false, 60000, 0.0, 0};

    if (g_ios_engine) {
        UserLocation location(latitude, longitude, speedMps);
        EngineResponse response = g_ios_engine->processLocation(location);
        result = make_result(response, 0);
    }

    return result;
}

GeoEngineResult ios_geo_engine_process_location_with_events(double latitude,
                                                            double longitude,
                                                            double speedMps,
                                                            GeoEngineTransition *outTransitions,
                                                            int maxTransitions) {
    GeoEngineResult result = {false, 60000, 0.0, 0};

    if (!g_ios_engine) {
        return result;
    }

    UserLocation location(latitude, longitude, speedMps);
    EngineResponse response = g_ios_engine->processLocation(location);

    const int copyCount = std::min(
        static_cast<int>(response.transitions.size()),
        std::max(0, maxTransitions)
    );

    g_ios_transition_ids.clear();
    g_ios_transition_ids.reserve(copyCount);
    for (int i = 0; i < copyCount; ++i) {
        g_ios_transition_ids.push_back(response.transitions[static_cast<size_t>(i)].zoneId);
    }

    if (outTransitions) {
        for (int i = 0; i < copyCount; ++i) {
            copy_transition(response.transitions[static_cast<size_t>(i)], outTransitions[i]);
            outTransitions[i].zoneId = g_ios_transition_ids[static_cast<size_t>(i)].c_str();
        }
    }

    return make_result(response, copyCount);
}

bool ios_geo_engine_update_zone_state(const char *zoneId,
                                      bool isInside,
                                      GeoEngineTransition *outTransition) {
    if (!g_ios_engine || !zoneId) {
        return false;
    }

    ZoneTransition transition;
    const bool shouldNotify = g_ios_engine->updateZoneState(std::string(zoneId), isInside, transition);
    if (!shouldNotify || !outTransition) {
        return shouldNotify;
    }

    g_ios_single_transition_id = transition.zoneId;
    copy_transition(transition, *outTransition);
    outTransition->zoneId = g_ios_single_transition_id.c_str();
    return true;
}

int ios_geo_engine_get_nearest_zones(double latitude,
                                     double longitude,
                                     GeoEngineNearestZone *outZones,
                                     int maxZones) {
    if (!g_ios_engine || !outZones || maxZones <= 0) {
        return 0;
    }

    const auto nearest = g_ios_engine->nearestZones(
        latitude,
        longitude,
        static_cast<size_t>(maxZones)
    );
    const int copyCount = static_cast<int>(nearest.size());

    g_ios_nearest_ids.clear();
    g_ios_nearest_ids.reserve(copyCount);
    for (int i = 0; i < copyCount; ++i) {
        g_ios_nearest_ids.push_back(nearest[static_cast<size_t>(i)].zoneId);
    }

    for (int i = 0; i < copyCount; ++i) {
        outZones[i].zoneId = g_ios_nearest_ids[static_cast<size_t>(i)].c_str();
        outZones[i].zoneIndex = nearest[static_cast<size_t>(i)].zoneIndex;
        outZones[i].distanceMeters = nearest[static_cast<size_t>(i)].distanceMeters;
    }

    return copyCount;
}

bool ios_geo_engine_has_moved_significantly(double fromLatitude,
                                            double fromLongitude,
                                            double toLatitude,
                                            double toLongitude,
                                            double thresholdMeters) {
    if (!g_ios_engine) {
        return true;
    }
    return g_ios_engine->hasMovedSignificantly(
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
        thresholdMeters
    );
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

bool ios_navigation_history_append_route_point(const char *directory,
                                               const char *dayKey,
                                               long long timestampMs,
                                               double latitude,
                                               double longitude,
                                               double speedMps) {
    if (!directory || !dayKey) {
        return false;
    }

    return g_ios_history_engine.appendRoutePoint(
        std::string(directory),
        std::string(dayKey),
        HistoryRoutePoint(
            static_cast<int64_t>(timestampMs),
            latitude,
            longitude,
            speedMps
        )
    );
}

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
                                               double longitude) {
    if (!directory || !dayKey) {
        return false;
    }

    HistoryAlertEvent event;
    event.id = eventId ? std::string(eventId) : std::string();
    event.alertId = alertId ? std::string(alertId) : std::string();
    event.task = task ? std::string(task) : std::string();
    event.place = place ? std::string(place) : std::string();
    event.address = address ? std::string(address) : std::string();
    event.eventType = eventType ? std::string(eventType) : std::string();
    event.timestampMs = static_cast<int64_t>(timestampMs);
    event.latitude = latitude;
    event.longitude = longitude;

    return g_ios_history_engine.appendAlertEvent(
        std::string(directory),
        std::string(dayKey),
        event
    );
}

int ios_navigation_history_list_day_summaries(const char *directory,
                                              NavigationHistoryDaySummaryResult *outSummaries,
                                              int maxSummaries) {
    if (!directory || !outSummaries || maxSummaries <= 0) {
        return 0;
    }

    const auto summaries = g_ios_history_engine.listDaySummaries(std::string(directory));
    const int copyCount = std::min(
        static_cast<int>(summaries.size()),
        std::max(0, maxSummaries)
    );

    g_ios_history_day_keys.clear();
    g_ios_history_day_keys.reserve(copyCount);
    for (int i = 0; i < copyCount; ++i) {
        g_ios_history_day_keys.push_back(summaries[static_cast<size_t>(i)].dayKey);
    }

    for (int i = 0; i < copyCount; ++i) {
        const auto& summary = summaries[static_cast<size_t>(i)];
        outSummaries[i].dayKey = g_ios_history_day_keys[static_cast<size_t>(i)].c_str();
        outSummaries[i].startTimestampMs = summary.startTimestampMs;
        outSummaries[i].endTimestampMs = summary.endTimestampMs;
        outSummaries[i].pointCount = summary.pointCount;
        outSummaries[i].alertEventCount = summary.alertEventCount;
        outSummaries[i].distanceMeters = summary.distanceMeters;
    }

    return copyCount;
}

const char *ios_navigation_history_load_day_json(const char *directory,
                                                 const char *dayKey) {
    if (!directory || !dayKey) {
        return nullptr;
    }

    g_ios_history_json = g_ios_history_engine.loadDayJson(
        std::string(directory),
        std::string(dayKey)
    );
    if (g_ios_history_json.empty()) {
        return nullptr;
    }
    return g_ios_history_json.c_str();
}

int ios_navigation_history_prune_before_day(const char *directory,
                                            const char *minimumDayKey) {
    if (!directory || !minimumDayKey) {
        return 0;
    }

    return g_ios_history_engine.pruneBeforeDay(
        std::string(directory),
        std::string(minimumDayKey)
    );
}

}
