#include "include/geo_engine.h"
#include <cmath>
#include <algorithm>

namespace geo_engine {

const double EARTH_RADIUS_METERS = 6371000.0;  // Earth radius in meters
const double DEG_TO_RAD = M_PI / 180.0;

GeoEngine::GeoEngine() : hasLastLocation(false) {}

GeoEngine::~GeoEngine() {}

void GeoEngine::initialize(const std::vector<GeofenceZone>& zones) {
    this->zones = zones;
    hasLastLocation = false;
}

void GeoEngine::addZone(const GeofenceZone& zone) {
    zones.push_back(zone);
}

void GeoEngine::removeZone(size_t index) {
    if (index < zones.size()) {
        zones.erase(zones.begin() + index);
    }
}

size_t GeoEngine::getZoneCount() const {
    return zones.size();
}

void GeoEngine::clearZones() {
    zones.clear();
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

        if (distance < zone.radiusMeters) {
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

    // Check zone containment
    auto [isInside, distanceToNearest] = checkZoneContainment(location);

    // Find the nearest zone for interval calculation
    double nearestZoneRadius = 100.0;  // Default radius
    for (const auto& zone : zones) {
        double dist = calculateDistance(location.latitude, location.longitude,
                                       zone.latitude, zone.longitude);
        if (dist == distanceToNearest) {
            nearestZoneRadius = zone.radiusMeters;
            break;
        }
    }

    // Calculate adaptive interval
    int64_t nextInterval = calculateAdaptiveInterval(location.speedMps, distanceToNearest, nearestZoneRadius);

    response.isInsideZone = isInside;
    response.nextIntervalMs = nextInterval;
    response.distanceMeters = distanceToNearest;

    lastLocation = location;
    hasLastLocation = true;

    return response;
}

}  // namespace geo_engine
