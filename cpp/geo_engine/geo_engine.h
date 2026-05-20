#ifndef GEO_ENGINE_H
#define GEO_ENGINE_H

#include <vector>
#include <cmath>

/**
 * User location with speed information
 */
struct UserLocation {
    double latitude;
    double longitude;
    double speedMps; // Speed in meters per second
};

/**
 * Geofence zone definition
 */
struct GeofenceZone {
    double latitude;
    double longitude;
    double radiusMeters;
};

/**
 * Engine response with zone status and recommendations
 */
struct EngineResponse {
    bool isInsideZone;
    long long nextIntervalMs; // Next tracking interval in milliseconds
    double distanceMeters;    // Distance to zone center
};

/**
 * Pure C++17 Geofencing Engine
 * Optimized for battery efficiency with adaptive tracking intervals
 */
class GeoEngine {
public:
    GeoEngine();
    ~GeoEngine();

    /**
     * Initialize the engine with default parameters
     */
    void initialize();

    /**
     * Add a geofence zone
     */
    void addZone(double latitude, double longitude, double radiusMeters);

    /**
     * Remove all zones
     */
    void clearZones();

    /**
     * Get current number of managed zones
     */
    int getZoneCount() const;

    /**
     * Process location update and return status
     */
    EngineResponse processLocation(const UserLocation& location);

private:
    std::vector<GeofenceZone> zones;

    /**
     * Calculate distance between two coordinates using Haversine formula
     * @return Distance in meters
     */
    double haversineDistance(double lat1, double lon1, double lat2, double lon2) const;

    /**
     * Calculate adaptive tracking interval based on speed and distance
     * @param speed Speed in m/s
     * @param distance Distance to nearest zone in meters
     * @param zoneRadius Radius of the zone in meters
     * @return Recommended interval in milliseconds
     */
    long long calculateAdaptiveInterval(double speed, double distance, double zoneRadius) const;

    /**
     * Check if location is inside any zone
     */
    bool isInsideAnyZone(const UserLocation& location, double& outNearestDistance) const;

    // Constants for interval calculation
    static constexpr long long MIN_INTERVAL_MS = 1000;      // 1 second
    static constexpr long long MAX_INTERVAL_MS = 120000;    // 2 minutes
    static constexpr double EARTH_RADIUS_METERS = 6371000.0; // Earth radius in meters
};

#endif // GEO_ENGINE_H
