#include "include/geo_engine.h"
#ifndef _USE_MATH_DEFINES
#define _USE_MATH_DEFINES
#endif
#include <cmath>
#include <algorithm>
#include <limits>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace geo_engine {

const double EARTH_RADIUS_METERS = 6371000.0;
const double DEG_TO_RAD          = M_PI / 180.0;

GeoEngine::GeoEngine() : hasLastLocation(false) {}
GeoEngine::~GeoEngine() {}

void GeoEngine::initialize(const std::vector<GeofenceZone>& zones) {
    clearZones();
    for (const auto& z : zones) {
        addZone(z);
    }
}

void GeoEngine::addZone(const GeofenceZone& zone) {
    GeofenceZone z = zone;
    if (z.radiusMeters < MIN_RADIUS_METERS) {
        z.radiusMeters = MIN_RADIUS_METERS;
    }
    // Preserve existing state if zone already tracked (re-add after config change)
    if (zoneStates.find(z.id) == zoneStates.end()) {
        zoneStates[z.id] = ZoneStatus{};
    }
    // Remove old entry with same id before pushing
    zones.erase(std::remove_if(zones.begin(), zones.end(),
        [&](const GeofenceZone& existing){ return existing.id == z.id; }), zones.end());
    zones.push_back(z);
}

void GeoEngine::removeZone(const std::string& zoneId) {
    zones.erase(std::remove_if(zones.begin(), zones.end(),
        [&](const GeofenceZone& z){ return z.id == zoneId; }), zones.end());
    zoneStates.erase(zoneId);
}

size_t GeoEngine::getZoneCount() const {
    return zones.size();
}

void GeoEngine::clearZones() {
    zones.clear();
    zoneStates.clear();
}

ZoneState GeoEngine::getZoneState(const std::string& zoneId) const {
    auto it = zoneStates.find(zoneId);
    if (it == zoneStates.end()) return ZoneState::OUTSIDE;
    return it->second.state;
}

double GeoEngine::calculateDistance(double lat1, double lon1,
                                    double lat2, double lon2) const {
    double dLat = (lat2 - lat1) * DEG_TO_RAD;
    double dLon = (lon2 - lon1) * DEG_TO_RAD;

    double a = std::sin(dLat / 2.0) * std::sin(dLat / 2.0) +
               std::cos(lat1 * DEG_TO_RAD) * std::cos(lat2 * DEG_TO_RAD) *
               std::sin(dLon / 2.0) * std::sin(dLon / 2.0);

    double c = 2.0 * std::atan2(std::sqrt(a), std::sqrt(1.0 - a));
    return EARTH_RADIUS_METERS * c;
}

int64_t GeoEngine::calculateAdaptiveInterval(double speedMps,
                                              double distanceToBoundary) const {
    // Speed-based base interval
    int64_t base;
    if (speedMps < 1.0) {
        base = 60000;
    } else if (speedMps < 5.0) {
        base = 10000;
    } else if (speedMps < 15.0) {
        base = 5000;
    } else {
        base = 2000;
    }

    // Proximity adjustment (distanceToBoundary = dist-to-center minus radius)
    // Negative value means already inside — speed alone governs.
    if (distanceToBoundary < 0.0) {
        // Inside zone: speed only
    } else if (distanceToBoundary < MIN_RADIUS_METERS) {
        // Approaching boundary: poll faster
        base = std::min(base, static_cast<int64_t>(5000));
    } else if (distanceToBoundary > MIN_RADIUS_METERS * 2.0) {
        // Far from all zones: poll slower
        base = base * 2;
    }

    return std::max(static_cast<int64_t>(1000),
           std::min(static_cast<int64_t>(120000), base));
}

EngineResponse GeoEngine::processLocation(const UserLocation& location) {
    EngineResponse response;

    if (zones.empty()) {
        response.isInsideAnyZone    = false;
        response.nextIntervalMs     = 60000;
        response.distanceToNearestMeters = 0.0;
        return response;
    }

    // Reject fixes that are too inaccurate to make reliable transition decisions
    if (location.accuracyMeters > MAX_ACCURACY_METERS) {
        response.nextIntervalMs = ACCURACY_WAIT_INTERVAL_MS;
        return response;
    }

    double minDistanceToBoundary = std::numeric_limits<double>::max();
    double nearestCenterDistance  = std::numeric_limits<double>::max();
    bool   insideAny              = false;

    for (const auto& zone : zones) {
        double distance = calculateDistance(location.latitude, location.longitude,
                                            zone.latitude, zone.longitude);
        double distToBoundary = distance - zone.radiusMeters;  // negative = inside
        double exitThreshold  = zone.radiusMeters + zone.exitBufferMeters;

        if (distance < nearestCenterDistance) {
            nearestCenterDistance = distance;
        }
        if (distToBoundary < minDistanceToBoundary) {
            minDistanceToBoundary = distToBoundary;
        }

        ZoneStatus& status = zoneStates[zone.id];

        switch (status.state) {
            case ZoneState::OUTSIDE:
                if (distance < zone.radiusMeters) {
                    status.state               = ZoneState::PENDING_ENTER;
                    status.pendingStateStartMs = location.timestampMs;
                }
                break;

            case ZoneState::PENDING_ENTER:
                if (distance >= zone.radiusMeters) {
                    // Moved back out before dwell — cancel
                    status.state               = ZoneState::OUTSIDE;
                    status.pendingStateStartMs = 0;
                } else if (location.timestampMs - status.pendingStateStartMs >= DWELL_ENTRY_MS) {
                    // Dwell satisfied — confirm ENTER
                    status.state               = ZoneState::INSIDE;
                    status.pendingStateStartMs = 0;
                    response.transitions.push_back({
                        zone.id, zone.name, TransitionType::ENTER,
                        distance, location.timestampMs
                    });
                }
                break;

            case ZoneState::INSIDE:
                insideAny = true;
                if (distance >= exitThreshold) {
                    status.state               = ZoneState::PENDING_EXIT;
                    status.pendingStateStartMs = location.timestampMs;
                }
                break;

            case ZoneState::PENDING_EXIT:
                insideAny = true;  // Still counts as inside until confirmed exit
                if (distance < zone.radiusMeters) {
                    // Re-entered before dwell — cancel exit
                    status.state               = ZoneState::INSIDE;
                    status.pendingStateStartMs = 0;
                } else if (location.timestampMs - status.pendingStateStartMs >= DWELL_EXIT_MS) {
                    // Dwell satisfied — confirm EXIT
                    status.state               = ZoneState::OUTSIDE;
                    status.pendingStateStartMs = 0;
                    response.transitions.push_back({
                        zone.id, zone.name, TransitionType::EXIT,
                        distance, location.timestampMs
                    });
                    insideAny = insideAny && false;  // re-check below
                }
                break;
        }
    }

    // Recompute isInsideAny cleanly after all state updates
    insideAny = false;
    for (const auto& zone : zones) {
        auto it = zoneStates.find(zone.id);
        if (it != zoneStates.end() &&
            (it->second.state == ZoneState::INSIDE ||
             it->second.state == ZoneState::PENDING_EXIT)) {
            insideAny = true;
            break;
        }
    }

    response.isInsideAnyZone         = insideAny;
    response.distanceToNearestMeters = nearestCenterDistance;
    response.nextIntervalMs          = calculateAdaptiveInterval(
        location.speedMps, minDistanceToBoundary);

    lastLocation     = location;
    hasLastLocation  = true;

    return response;
}

bool GeoEngine::updateZoneState(const std::string& zoneId, bool isInside,
                                ZoneTransition& transition) {
    const int index = findZoneIndexById(zoneId);
    if (index < 0) {
        return false;
    }

    const auto& zone = zones[static_cast<size_t>(index)];
    const std::string key = keyForZone(static_cast<size_t>(index));
    const bool wasInside = insideStates.count(key) > 0 ? insideStates[key] : false;

    if (wasInside == isInside) {
        return false;
    }

    insideStates[key] = isInside;
    if (!shouldNotify(zone, isInside)) {
        return false;
    }

    transition = ZoneTransition(zone.id, isInside, 0.0, index);
    return true;
}

std::vector<NearestZone> GeoEngine::nearestZones(double latitude, double longitude,
                                                 size_t maxCount) const {
    std::vector<NearestZone> nearest;
    nearest.reserve(zones.size());

    for (size_t i = 0; i < zones.size(); ++i) {
        const auto& zone = zones[i];
        const double distance = calculateDistance(latitude, longitude,
                                                  zone.latitude, zone.longitude);
        nearest.emplace_back(zone.id, static_cast<int>(i), distance);
    }

    std::sort(nearest.begin(), nearest.end(), [](const NearestZone& a, const NearestZone& b) {
        if (a.distanceMeters == b.distanceMeters) {
            return a.zoneIndex < b.zoneIndex;
        }
        return a.distanceMeters < b.distanceMeters;
    });

    if (nearest.size() > maxCount) {
        nearest.resize(maxCount);
    }
    return nearest;
}

bool GeoEngine::hasMovedSignificantly(double fromLatitude, double fromLongitude,
                                      double toLatitude, double toLongitude,
                                      double thresholdMeters) const {
    if (thresholdMeters <= 0.0) {
        return true;
    }
    const double distance = calculateDistance(fromLatitude, fromLongitude,
                                              toLatitude, toLongitude);
    return distance >= thresholdMeters;
}

std::string GeoEngine::keyForZone(size_t index) const {
    if (index >= zones.size()) {
        return "";
    }
    if (!zones[index].id.empty()) {
        return zones[index].id;
    }
    return "#" + std::to_string(index);
}

int GeoEngine::findZoneIndexById(const std::string& zoneId) const {
    for (size_t i = 0; i < zones.size(); ++i) {
        if (zones[i].id == zoneId) {
            return static_cast<int>(i);
        }
    }
    return -1;
}

bool GeoEngine::shouldNotify(const GeofenceZone& zone, bool isInside) const {
    return isInside ? zone.notifyOnEntry : zone.notifyOnExit;
}

}  // namespace geo_engine
