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

const double EARTH_RADIUS_METERS = 6371000.0;  // Earth radius in meters
const double DEG_TO_RAD = M_PI / 180.0;

GeoEngine::GeoEngine() : hasLastLocation(false) {}

GeoEngine::~GeoEngine() {}

void GeoEngine::initialize(const std::vector<GeofenceZone>& zones) {
    this->zones = zones;
    insideStates.clear();
    hasLastLocation = false;
}

void GeoEngine::addZone(const GeofenceZone& zone) {
    zones.push_back(zone);
}

void GeoEngine::removeZone(size_t index) {
    if (index < zones.size()) {
        zones.erase(zones.begin() + index);
        insideStates.clear();
    }
}

size_t GeoEngine::getZoneCount() const {
    return zones.size();
}

void GeoEngine::clearZones() {
    zones.clear();
    insideStates.clear();
}

double GeoEngine::calculateDistance(double lat1, double lon1, double lat2, double lon2) const {
    double dLat = (lat2 - lat1) * DEG_TO_RAD;
    double dLon = (lon2 - lon1) * DEG_TO_RAD;

    double a = std::sin(dLat / 2.0) * std::sin(dLat / 2.0) +
               std::cos(lat1 * DEG_TO_RAD) * std::cos(lat2 * DEG_TO_RAD) *
               std::sin(dLon / 2.0) * std::sin(dLon / 2.0);

    double c = 2.0 * std::atan2(std::sqrt(a), std::sqrt(1.0 - a));
    return EARTH_RADIUS_METERS * c;
}

std::pair<bool, double> GeoEngine::checkZoneContainment(const UserLocation& location) const {
    if (zones.empty()) {
        return {false, std::numeric_limits<double>::max()};
    }

    double nearestDistance = std::numeric_limits<double>::max();
    bool isInsideAny = false;

    for (const auto& zone : zones) {
        double distance = calculateDistance(location.latitude, location.longitude,
                                           zone.latitude, zone.longitude);

        if (distance <= zone.radiusMeters) {
            isInsideAny = true;
        }

        nearestDistance = std::min(nearestDistance, distance);
    }

    return {isInsideAny, nearestDistance};
}

int64_t GeoEngine::calculateAdaptiveInterval(double speedMps, double distanceToNearestZone,
                                            double radiusOfNearestZone) const {
    int64_t baseInterval = 60000;  // 60 seconds default

    // Adjust based on speed
    if (speedMps < 1.0) {
        baseInterval = 60000;  // 60 seconds when stationary
    } else if (speedMps < 5.0) {
        baseInterval = 10000;  // 10 seconds when walking
    } else if (speedMps < 15.0) {
        baseInterval = 5000;   // 5 seconds when running/cycling
    } else {
        baseInterval = 2000;   // 2 seconds when moving fast
    }

    // Adjust based on distance to zone
    if (distanceToNearestZone > radiusOfNearestZone * 2.0) {
        baseInterval *= 2;  // Double interval when far from zone
    } else if (distanceToNearestZone < radiusOfNearestZone * 0.5) {
        baseInterval = std::min(baseInterval, static_cast<int64_t>(5000));
    }

    // Clamp to min/max bounds
    baseInterval = std::max(static_cast<int64_t>(1000),   baseInterval);
    baseInterval = std::min(static_cast<int64_t>(120000), baseInterval);

    return baseInterval;
}

EngineResponse GeoEngine::processLocation(const UserLocation& location) {
    EngineResponse response;

    if (zones.empty()) {
        response.isInsideZone = false;
        response.nextIntervalMs = 60000;
        response.distanceMeters = 0.0;
        return response;
    }

    double distanceToNearest = std::numeric_limits<double>::max();
    double nearestZoneRadius = 100.0;  // Default radius
    bool isInsideAny = false;

    for (size_t i = 0; i < zones.size(); ++i) {
        const auto& zone = zones[i];
        const double distance = calculateDistance(location.latitude, location.longitude,
                                                  zone.latitude, zone.longitude);
        const bool isInside = distance <= zone.radiusMeters;
        isInsideAny = isInsideAny || isInside;

        if (distance < distanceToNearest) {
            distanceToNearest = distance;
            nearestZoneRadius = zone.radiusMeters;
        }

        const std::string key = keyForZone(i);
        const bool wasInside = insideStates.count(key) > 0 ? insideStates[key] : false;
        if (wasInside != isInside) {
            insideStates[key] = isInside;
            if (shouldNotify(zone, isInside)) {
                response.transitions.emplace_back(zone.id, isInside, distance, static_cast<int>(i));
            }
        }
    }

    // Calculate adaptive interval
    int64_t nextInterval = calculateAdaptiveInterval(location.speedMps, distanceToNearest, nearestZoneRadius);

    response.isInsideZone = isInsideAny;
    response.nextIntervalMs = nextInterval;
    response.distanceMeters = distanceToNearest;

    lastLocation = location;
    hasLastLocation = true;

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
