#include "GeoEngineWrapper.h"
#include "geo_engine.h"
#include "history_engine.h"
#include <algorithm>
#include <memory>
#include <cstring>

using namespace geo_engine;

static std::unique_ptr<GeoEngine> g_ios_engine = nullptr;
static NavigationHistoryEngine g_ios_history_engine;
static thread_local std::vector<std::string> g_ios_transition_ids;
static thread_local std::vector<std::string> g_ios_nearest_ids;
static thread_local std::string g_ios_single_transition_id;
static thread_local std::vector<std::string> g_ios_history_day_keys;
static thread_local std::string g_ios_history_json;

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
        result.transitions[i].latitude      = t.latitude;
        result.transitions[i].longitude     = t.longitude;
        result.transitions[i].speedMps      = t.speedMps;
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

bool ios_navigation_history_append_activity_event(const char *directory,
                                                  const char *dayKey,
                                                  long long timestampMs,
                                                  const char *activityType,
                                                  const char *confidence) {
    if (!directory || !dayKey) {
        return false;
    }

    HistoryActivityEvent event(
        static_cast<int64_t>(timestampMs),
        activityType ? std::string(activityType) : std::string(),
        confidence ? std::string(confidence) : std::string()
    );

    return g_ios_history_engine.appendActivityEvent(
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

}  // extern "C"
