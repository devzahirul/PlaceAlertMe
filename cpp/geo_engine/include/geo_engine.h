#ifndef GEO_ENGINE_H
#define GEO_ENGINE_H

#include <vector>
#include <cstdint>

namespace geo_engine {

/**
 * Represents a geographic coordinate with speed information
 */
struct UserLocation {
    double latitude;
    double longitude;
    double speedMps;  // Speed in meters per second
    
    UserLocation() : latitude(0.0), longitude(0.0), speedMps(0.0) {}
    
    UserLocation(double lat, double lon, double speed)
        : latitude(lat), longitude(lon), speedMps(speed) {}
};

/**
 * Represents a circular geofence zone
 */
struct GeofenceZone {
    double latitude;
    double longitude;
    double radiusMeters;
    
    GeofenceZone() : latitude(0.0), longitude(0.0), radiusMeters(0.0) {}
    
    GeofenceZone(double lat, double lon, double radius)
        : latitude(lat), longitude(lon), radiusMeters(radius) {}
};

/**
 * Engine response containing zone status and recommended tracking interval
 */
struct EngineResponse {
    bool isInsideZone;
    int64_t nextIntervalMs;  // Next tracking interval recommendation in milliseconds
    double distanceMeters;   // Distance to zone center
    
    EngineResponse() 
        : isInsideZone(false), nextIntervalMs(60000), distanceMeters(0.0) {}
};

/**
 * Core geofencing engine
 * Handles distance calculations, zone detection, and adaptive interval management
 */
class GeoEngine {
public:
    GeoEngine();
    ~GeoEngine();
    
    /**
     * Initialize the engine with geofence zones
     * @param zones Vector of GeofenceZone objects
     */
    void initialize(const std::vector<GeofenceZone>& zones);
    
    /**
     * Process a user location and return engine response
     * @param location Current user location
     * @return EngineResponse containing zone status and next tracking interval
     */
    EngineResponse processLocation(const UserLocation& location);
    
    /**
     * Add a new geofence zone
     * @param zone GeofenceZone to add
     */
    void addZone(const GeofenceZone& zone);
    
    /**
     * Remove a geofence zone by index
     * @param index Index of zone to remove
     */
    void removeZone(size_t index);
    
    /**
     * Get number of managed zones
     * @return Number of zones
     */
    size_t getZoneCount() const;
    
    /**
     * Clear all zones
     */
    void clearZones();

private:
    std::vector<GeofenceZone> zones;
    UserLocation lastLocation;
    bool hasLastLocation;
    
    /**
     * Calculate distance between two coordinates using Haversine formula
     * @param lat1 Latitude of point 1
     * @param lon1 Longitude of point 1
     * @param lat2 Latitude of point 2
     * @param lon2 Longitude of point 2
     * @return Distance in meters
     */
    double calculateDistance(double lat1, double lon1, double lat2, double lon2) const;
    
    /**
     * Calculate adaptive tracking interval based on speed and distance
     * @param speedMps Speed in meters per second
     * @param distanceToNearestZone Distance to nearest zone center
     * @param radiusOfNearestZone Radius of nearest zone
     * @return Recommended next interval in milliseconds
     */
    int64_t calculateAdaptiveInterval(double speedMps, double distanceToNearestZone, 
                                      double radiusOfNearestZone) const;
    
    /**
     * Check if location is inside any geofence zone
     * @param location User location
     * @return Pair of (isInside, distanceToNearestZone)
     */
    std::pair<bool, double> checkZoneContainment(const UserLocation& location) const;
};

}  // namespace geo_engine

#endif // GEO_ENGINE_H
