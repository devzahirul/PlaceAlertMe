#ifndef HISTORY_ENGINE_H
#define HISTORY_ENGINE_H

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace geo_engine {

struct HistoryRoutePoint {
    int64_t timestampMs;
    double latitude;
    double longitude;
    double speedMps;

    HistoryRoutePoint()
        : timestampMs(0), latitude(0.0), longitude(0.0), speedMps(0.0) {}

    HistoryRoutePoint(int64_t timestamp, double lat, double lon, double speed)
        : timestampMs(timestamp), latitude(lat), longitude(lon), speedMps(speed) {}
};

struct HistoryAlertEvent {
    std::string id;
    int64_t timestampMs;
    std::string alertId;
    std::string task;
    std::string place;
    std::string address;
    std::string eventType;
    double latitude;
    double longitude;

    HistoryAlertEvent()
        : timestampMs(0), latitude(0.0), longitude(0.0) {}
};

struct HistoryActivityEvent {
    int64_t timestampMs;
    std::string activityType;
    std::string confidence;

    HistoryActivityEvent()
        : timestampMs(0) {}

    HistoryActivityEvent(int64_t timestamp, std::string type, std::string confidenceValue)
        : timestampMs(timestamp), activityType(std::move(type)), confidence(std::move(confidenceValue)) {}
};

struct HistoryDaySummary {
    std::string dayKey;
    int64_t startTimestampMs;
    int64_t endTimestampMs;
    int pointCount;
    int alertEventCount;
    double distanceMeters;

    HistoryDaySummary()
        : startTimestampMs(0), endTimestampMs(0), pointCount(0),
          alertEventCount(0), distanceMeters(0.0) {}
};

struct HistoryDay {
    std::string dayKey;
    std::vector<HistoryRoutePoint> points;
    std::vector<HistoryAlertEvent> alertEvents;
    std::vector<HistoryActivityEvent> activityEvents;
    HistoryDaySummary summary;
};

class NavigationHistoryEngine {
public:
    bool appendRoutePoint(const std::string& directory,
                          const std::string& dayKey,
                          const HistoryRoutePoint& point,
                          double minDistanceMeters = 10.0,
                          int64_t minIntervalMs = 60000) const;

    bool appendAlertEvent(const std::string& directory,
                          const std::string& dayKey,
                          const HistoryAlertEvent& event) const;

    bool appendActivityEvent(const std::string& directory,
                             const std::string& dayKey,
                             const HistoryActivityEvent& event) const;

    bool loadDay(const std::string& directory,
                 const std::string& dayKey,
                 HistoryDay& outDay) const;

    std::string loadDayJson(const std::string& directory,
                            const std::string& dayKey) const;

    std::vector<HistoryDaySummary> listDaySummaries(const std::string& directory) const;

    int pruneBeforeDay(const std::string& directory,
                       const std::string& minimumDayKey) const;

    static double calculateDistance(double lat1, double lon1, double lat2, double lon2);

private:
    std::string filePath(const std::string& directory, const std::string& dayKey) const;
    bool isValidDayKey(const std::string& dayKey) const;
    bool appendLine(const std::string& path, const std::string& line) const;
    HistoryDaySummary summarize(const std::string& dayKey,
                                const std::vector<HistoryRoutePoint>& points,
                                const std::vector<HistoryAlertEvent>& events) const;
};

}  // namespace geo_engine

#endif  // HISTORY_ENGINE_H
