#include "include/history_engine.h"

#ifndef _USE_MATH_DEFINES
#define _USE_MATH_DEFINES
#endif

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fstream>
#include <iomanip>
#include <limits>
#include <sstream>
#include <sys/stat.h>
#include <unistd.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace geo_engine {
namespace {

constexpr double kEarthRadiusMeters = 6371000.0;
constexpr double kDegToRad = M_PI / 180.0;

bool hasSuffix(const std::string& value, const std::string& suffix) {
    return value.size() >= suffix.size() &&
           value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
}

std::string joinPath(const std::string& directory, const std::string& filename) {
    if (directory.empty()) {
        return filename;
    }
    if (directory.back() == '/') {
        return directory + filename;
    }
    return directory + "/" + filename;
}

std::string escapeJson(const std::string& value) {
    std::ostringstream out;
    for (char c : value) {
        switch (c) {
        case '"':
            out << "\\\"";
            break;
        case '\\':
            out << "\\\\";
            break;
        case '\n':
            out << "\\n";
            break;
        case '\r':
            out << "\\r";
            break;
        case '\t':
            out << "\\t";
            break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                out << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                    << static_cast<int>(static_cast<unsigned char>(c));
            } else {
                out << c;
            }
            break;
        }
    }
    return out.str();
}

std::string unescapeJson(const std::string& value) {
    std::ostringstream out;
    for (size_t i = 0; i < value.size(); ++i) {
        const char c = value[i];
        if (c != '\\' || i + 1 >= value.size()) {
            out << c;
            continue;
        }

        const char escaped = value[++i];
        switch (escaped) {
        case '"':
            out << '"';
            break;
        case '\\':
            out << '\\';
            break;
        case 'n':
            out << '\n';
            break;
        case 'r':
            out << '\r';
            break;
        case 't':
            out << '\t';
            break;
        default:
            out << escaped;
            break;
        }
    }
    return out.str();
}

std::string numberToString(double value) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(8) << value;
    return out.str();
}

size_t valueStart(const std::string& line, const std::string& key) {
    const std::string marker = "\"" + key + "\":";
    const size_t markerPos = line.find(marker);
    if (markerPos == std::string::npos) {
        return std::string::npos;
    }
    size_t pos = markerPos + marker.size();
    while (pos < line.size() && (line[pos] == ' ' || line[pos] == '\t')) {
        ++pos;
    }
    return pos;
}

bool extractString(const std::string& line, const std::string& key, std::string& outValue) {
    size_t pos = valueStart(line, key);
    if (pos == std::string::npos || pos >= line.size() || line[pos] != '"') {
        return false;
    }

    ++pos;
    std::ostringstream raw;
    bool escaping = false;
    for (; pos < line.size(); ++pos) {
        const char c = line[pos];
        if (escaping) {
            raw << '\\' << c;
            escaping = false;
        } else if (c == '\\') {
            escaping = true;
        } else if (c == '"') {
            outValue = unescapeJson(raw.str());
            return true;
        } else {
            raw << c;
        }
    }
    return false;
}

bool extractInt64(const std::string& line, const std::string& key, int64_t& outValue) {
    const size_t pos = valueStart(line, key);
    if (pos == std::string::npos) {
        return false;
    }
    char* end = nullptr;
    errno = 0;
    const long long parsed = std::strtoll(line.c_str() + pos, &end, 10);
    if (errno != 0 || end == line.c_str() + pos) {
        return false;
    }
    outValue = static_cast<int64_t>(parsed);
    return true;
}

bool extractDouble(const std::string& line, const std::string& key, double& outValue) {
    const size_t pos = valueStart(line, key);
    if (pos == std::string::npos) {
        return false;
    }
    char* end = nullptr;
    errno = 0;
    const double parsed = std::strtod(line.c_str() + pos, &end);
    if (errno != 0 || end == line.c_str() + pos) {
        return false;
    }
    outValue = parsed;
    return true;
}

std::string pointLine(const HistoryRoutePoint& point) {
    return "{\"type\":\"point\",\"timestampMs\":" + std::to_string(point.timestampMs) +
           ",\"latitude\":" + numberToString(point.latitude) +
           ",\"longitude\":" + numberToString(point.longitude) +
           ",\"speedMps\":" + numberToString(point.speedMps) + "}";
}

std::string eventLine(const HistoryAlertEvent& event) {
    const std::string id = event.id.empty()
        ? std::to_string(event.timestampMs) + "-" + event.alertId + "-" + event.eventType
        : event.id;

    return "{\"type\":\"alert\",\"id\":\"" + escapeJson(id) +
           "\",\"timestampMs\":" + std::to_string(event.timestampMs) +
           ",\"alertId\":\"" + escapeJson(event.alertId) +
           "\",\"task\":\"" + escapeJson(event.task) +
           "\",\"place\":\"" + escapeJson(event.place) +
           "\",\"address\":\"" + escapeJson(event.address) +
           "\",\"eventType\":\"" + escapeJson(event.eventType) +
           "\",\"latitude\":" + numberToString(event.latitude) +
           ",\"longitude\":" + numberToString(event.longitude) + "}";
}

bool parsePointLine(const std::string& line, HistoryRoutePoint& point) {
    return extractInt64(line, "timestampMs", point.timestampMs) &&
           extractDouble(line, "latitude", point.latitude) &&
           extractDouble(line, "longitude", point.longitude) &&
           extractDouble(line, "speedMps", point.speedMps);
}

bool parseEventLine(const std::string& line, HistoryAlertEvent& event) {
    bool ok = true;
    ok = extractString(line, "id", event.id) && ok;
    ok = extractInt64(line, "timestampMs", event.timestampMs) && ok;
    ok = extractString(line, "alertId", event.alertId) && ok;
    ok = extractString(line, "task", event.task) && ok;
    ok = extractString(line, "place", event.place) && ok;
    ok = extractString(line, "address", event.address) && ok;
    ok = extractString(line, "eventType", event.eventType) && ok;
    ok = extractDouble(line, "latitude", event.latitude) && ok;
    ok = extractDouble(line, "longitude", event.longitude) && ok;
    return ok;
}

}  // namespace

bool NavigationHistoryEngine::appendRoutePoint(const std::string& directory,
                                               const std::string& dayKey,
                                               const HistoryRoutePoint& point,
                                               double minDistanceMeters,
                                               int64_t minIntervalMs) const {
    if (!isValidDayKey(dayKey)) {
        return false;
    }

    HistoryDay day;
    loadDay(directory, dayKey, day);

    if (!day.points.empty()) {
        const HistoryRoutePoint& last = day.points.back();
        const double distance = calculateDistance(
            last.latitude,
            last.longitude,
            point.latitude,
            point.longitude
        );
        const int64_t elapsedMs = point.timestampMs - last.timestampMs;
        if (distance < minDistanceMeters && elapsedMs < minIntervalMs) {
            return false;
        }
    }

    return appendLine(filePath(directory, dayKey), pointLine(point));
}

bool NavigationHistoryEngine::appendAlertEvent(const std::string& directory,
                                               const std::string& dayKey,
                                               const HistoryAlertEvent& event) const {
    if (!isValidDayKey(dayKey)) {
        return false;
    }
    return appendLine(filePath(directory, dayKey), eventLine(event));
}

bool NavigationHistoryEngine::loadDay(const std::string& directory,
                                      const std::string& dayKey,
                                      HistoryDay& outDay) const {
    outDay = HistoryDay();
    outDay.dayKey = dayKey;

    if (!isValidDayKey(dayKey)) {
        return false;
    }

    std::ifstream input(filePath(directory, dayKey));
    if (!input.good()) {
        outDay.summary = summarize(dayKey, outDay.points, outDay.alertEvents);
        return true;
    }

    std::string line;
    while (std::getline(input, line)) {
        std::string type;
        if (!extractString(line, "type", type)) {
            continue;
        }

        if (type == "point") {
            HistoryRoutePoint point;
            if (parsePointLine(line, point)) {
                outDay.points.push_back(point);
            }
        } else if (type == "alert") {
            HistoryAlertEvent event;
            if (parseEventLine(line, event)) {
                outDay.alertEvents.push_back(event);
            }
        }
    }

    std::sort(outDay.points.begin(), outDay.points.end(),
              [](const HistoryRoutePoint& lhs, const HistoryRoutePoint& rhs) {
                  return lhs.timestampMs < rhs.timestampMs;
              });
    std::sort(outDay.alertEvents.begin(), outDay.alertEvents.end(),
              [](const HistoryAlertEvent& lhs, const HistoryAlertEvent& rhs) {
                  return lhs.timestampMs < rhs.timestampMs;
              });

    outDay.summary = summarize(dayKey, outDay.points, outDay.alertEvents);
    return true;
}

std::string NavigationHistoryEngine::loadDayJson(const std::string& directory,
                                                 const std::string& dayKey) const {
    HistoryDay day;
    if (!loadDay(directory, dayKey, day)) {
        return "";
    }

    std::ostringstream out;
    out << "{\"dayKey\":\"" << escapeJson(day.dayKey) << "\",";
    out << "\"summary\":{";
    out << "\"dayKey\":\"" << escapeJson(day.summary.dayKey) << "\",";
    out << "\"startTimestampMs\":" << day.summary.startTimestampMs << ",";
    out << "\"endTimestampMs\":" << day.summary.endTimestampMs << ",";
    out << "\"pointCount\":" << day.summary.pointCount << ",";
    out << "\"alertEventCount\":" << day.summary.alertEventCount << ",";
    out << "\"distanceMeters\":" << numberToString(day.summary.distanceMeters);
    out << "},\"points\":[";

    for (size_t i = 0; i < day.points.size(); ++i) {
        if (i > 0) {
            out << ",";
        }
        out << pointLine(day.points[i]);
    }

    out << "],\"alertEvents\":[";
    for (size_t i = 0; i < day.alertEvents.size(); ++i) {
        if (i > 0) {
            out << ",";
        }
        out << eventLine(day.alertEvents[i]);
    }
    out << "]}";
    return out.str();
}

std::vector<HistoryDaySummary> NavigationHistoryEngine::listDaySummaries(const std::string& directory) const {
    std::vector<HistoryDaySummary> summaries;
    DIR* dir = opendir(directory.c_str());
    if (!dir) {
        return summaries;
    }

    while (dirent* entry = readdir(dir)) {
        const std::string name(entry->d_name);
        if (!hasSuffix(name, ".jsonl")) {
            continue;
        }

        const std::string dayKey = name.substr(0, name.size() - 6);
        if (!isValidDayKey(dayKey)) {
            continue;
        }

        HistoryDay day;
        if (loadDay(directory, dayKey, day) &&
            (day.summary.pointCount > 0 || day.summary.alertEventCount > 0)) {
            summaries.push_back(day.summary);
        }
    }
    closedir(dir);

    std::sort(summaries.begin(), summaries.end(),
              [](const HistoryDaySummary& lhs, const HistoryDaySummary& rhs) {
                  return lhs.dayKey > rhs.dayKey;
              });
    return summaries;
}

int NavigationHistoryEngine::pruneBeforeDay(const std::string& directory,
                                            const std::string& minimumDayKey) const {
    if (!isValidDayKey(minimumDayKey)) {
        return 0;
    }

    int removed = 0;
    DIR* dir = opendir(directory.c_str());
    if (!dir) {
        return removed;
    }

    while (dirent* entry = readdir(dir)) {
        const std::string name(entry->d_name);
        if (!hasSuffix(name, ".jsonl")) {
            continue;
        }

        const std::string dayKey = name.substr(0, name.size() - 6);
        if (isValidDayKey(dayKey) && dayKey < minimumDayKey) {
            if (std::remove(joinPath(directory, name).c_str()) == 0) {
                ++removed;
            }
        }
    }

    closedir(dir);
    return removed;
}

double NavigationHistoryEngine::calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double dLat = (lat2 - lat1) * kDegToRad;
    const double dLon = (lon2 - lon1) * kDegToRad;
    const double a = std::sin(dLat / 2.0) * std::sin(dLat / 2.0) +
                     std::cos(lat1 * kDegToRad) * std::cos(lat2 * kDegToRad) *
                     std::sin(dLon / 2.0) * std::sin(dLon / 2.0);
    const double c = 2.0 * std::atan2(std::sqrt(a), std::sqrt(1.0 - a));
    return kEarthRadiusMeters * c;
}

std::string NavigationHistoryEngine::filePath(const std::string& directory,
                                              const std::string& dayKey) const {
    return joinPath(directory, dayKey + ".jsonl");
}

bool NavigationHistoryEngine::isValidDayKey(const std::string& dayKey) const {
    if (dayKey.size() != 10 || dayKey[4] != '-' || dayKey[7] != '-') {
        return false;
    }
    for (size_t i = 0; i < dayKey.size(); ++i) {
        if (i == 4 || i == 7) {
            continue;
        }
        if (dayKey[i] < '0' || dayKey[i] > '9') {
            return false;
        }
    }
    return true;
}

bool NavigationHistoryEngine::appendLine(const std::string& path,
                                         const std::string& line) const {
    std::ofstream output(path, std::ios::out | std::ios::app);
    if (!output.good()) {
        return false;
    }
    output << line << "\n";
    return output.good();
}

HistoryDaySummary NavigationHistoryEngine::summarize(
    const std::string& dayKey,
    const std::vector<HistoryRoutePoint>& points,
    const std::vector<HistoryAlertEvent>& events
) const {
    HistoryDaySummary summary;
    summary.dayKey = dayKey;
    summary.pointCount = static_cast<int>(points.size());
    summary.alertEventCount = static_cast<int>(events.size());

    int64_t start = std::numeric_limits<int64_t>::max();
    int64_t end = 0;

    for (const auto& point : points) {
        start = std::min(start, point.timestampMs);
        end = std::max(end, point.timestampMs);
    }
    for (const auto& event : events) {
        start = std::min(start, event.timestampMs);
        end = std::max(end, event.timestampMs);
    }

    summary.startTimestampMs = start == std::numeric_limits<int64_t>::max() ? 0 : start;
    summary.endTimestampMs = end;

    double distance = 0.0;
    for (size_t i = 1; i < points.size(); ++i) {
        distance += calculateDistance(
            points[i - 1].latitude,
            points[i - 1].longitude,
            points[i].latitude,
            points[i].longitude
        );
    }
    summary.distanceMeters = distance;
    return summary;
}

}  // namespace geo_engine
