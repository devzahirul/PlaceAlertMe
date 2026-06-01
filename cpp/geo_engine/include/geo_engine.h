#ifndef GEO_ENGINE_H
#define GEO_ENGINE_H

#include <vector>
#include <string>
#include <unordered_map>
#include <cstdint>
#include <limits>

namespace geo_engine {

// Life360-parity constants
static constexpr double  MIN_RADIUS_METERS        = 150.0;
static constexpr double  MAX_ACCURACY_METERS       = 65.0;
static constexpr double  EXIT_BUFFER_METERS        = 50.0;
static constexpr int64_t DWELL_ENTRY_MS            = 10000;
static constexpr int64_t DWELL_EXIT_MS             = 10000;
static constexpr int64_t ACCURACY_WAIT_INTERVAL_MS = 5000;

struct UserLocation {
    double  latitude;
    double  longitude;
    double  speedMps;
    double  accuracyMeters;
    int64_t timestampMs;

    UserLocation()
        : latitude(0.0), longitude(0.0), speedMps(0.0),
          accuracyMeters(0.0), timestampMs(0) {}

    UserLocation(double lat, double lon, double speed,
                 double accuracy = 10.0, int64_t ts = 0)
        : latitude(lat), longitude(lon), speedMps(speed),
          accuracyMeters(accuracy), timestampMs(ts) {}
};

struct GeofenceZone {
    std::string id;
    std::string name;
    double latitude;
    double longitude;
    double radiusMeters;
    double exitBufferMeters;

    GeofenceZone()
        : latitude(0.0), longitude(0.0),
          radiusMeters(MIN_RADIUS_METERS), exitBufferMeters(EXIT_BUFFER_METERS) {}

    GeofenceZone(const std::string& id, const std::string& name,
                 double lat, double lon, double radius)
        : id(id), name(name), latitude(lat), longitude(lon),
          radiusMeters(radius < MIN_RADIUS_METERS ? MIN_RADIUS_METERS : radius),
          exitBufferMeters(EXIT_BUFFER_METERS) {}
};

enum class TransitionType { ENTER, EXIT };

struct ZoneTransition {
    std::string    zoneId;
    std::string    zoneName;
    TransitionType type;
    double         distanceMeters;
    double         latitude;
    double         longitude;
    double         speedMps;
    int64_t        timestampMs;
};

struct EngineResponse {
    bool                       isInsideAnyZone      = false;
    int64_t                    nextIntervalMs        = 60000;
    double                     distanceToNearestMeters = 0.0;
    std::vector<ZoneTransition> transitions;
};

// Per-zone state machine state (private to engine, exposed in header for tests)
enum class ZoneState { OUTSIDE, PENDING_ENTER, INSIDE, PENDING_EXIT };

struct ZoneStatus {
    ZoneState state              = ZoneState::OUTSIDE;
    int64_t   pendingStateStartMs = 0;
};

class GeoEngine {
public:
    GeoEngine();
    ~GeoEngine();

    void initialize(const std::vector<GeofenceZone>& zones);
    EngineResponse processLocation(const UserLocation& location);

    void   addZone(const GeofenceZone& zone);
    void   removeZone(const std::string& zoneId);
    size_t getZoneCount() const;
    void   clearZones();

    // Exposed for testing
    ZoneState getZoneState(const std::string& zoneId) const;

private:
    std::vector<GeofenceZone>                    zones;
    std::unordered_map<std::string, ZoneStatus>  zoneStates;
    UserLocation lastLocation;
    bool         hasLastLocation;

    double  calculateDistance(double lat1, double lon1,
                              double lat2, double lon2) const;
    int64_t calculateAdaptiveInterval(double speedMps,
                                      double distanceToBoundary) const;
};

}  // namespace geo_engine

#endif // GEO_ENGINE_H
