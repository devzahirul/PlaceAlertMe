#include <jni.h>
#include "geo_engine.h"
#include "history_engine.h"
#include <algorithm>
#include <memory>
#include <sstream>
#include <string>
#include <sstream>

static std::unique_ptr<geo_engine::GeoEngine> g_engine = nullptr;
static geo_engine::NavigationHistoryEngine g_history_engine;

static std::string stringFromJString(JNIEnv* env, jstring value) {
    if (!value) {
        return "";
    }
    const char* raw = env->GetStringUTFChars(value, nullptr);
    std::string result = raw ? std::string(raw) : std::string();
    if (raw) {
        env->ReleaseStringUTFChars(value, raw);
    }
    return result;
}

static std::string escapeJsonString(const std::string& value) {
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
                out << "\\u00";
                const char* hex = "0123456789abcdef";
                out << hex[(static_cast<unsigned char>(c) >> 4) & 0x0F];
                out << hex[static_cast<unsigned char>(c) & 0x0F];
            } else {
                out << c;
            }
            break;
        }
    }
    return out.str();
}

// Build a JSON string from EngineResponse for return to Kotlin.
// Uses manual construction to avoid any third-party dependency.
static std::string responseToJson(const geo_engine::EngineResponse& r) {
    std::ostringstream os;
    os << "{\"isInsideAny\":" << (r.isInsideAnyZone ? 1 : 0)
       << ",\"nextIntervalMs\":" << r.nextIntervalMs
       << ",\"distanceMeters\":" << r.distanceToNearestMeters
       << ",\"transitions\":[";
    for (size_t i = 0; i < r.transitions.size(); ++i) {
        const auto& t = r.transitions[i];
        if (i > 0) os << ",";
        os << "{\"zoneId\":\"" << t.zoneId << "\""
           << ",\"zoneName\":\"" << t.zoneName << "\""
           << ",\"type\":\"" << (t.type == geo_engine::TransitionType::ENTER ? "ENTER" : "EXIT") << "\""
           << ",\"distanceMeters\":" << t.distanceMeters
           << ",\"latitude\":" << t.latitude
           << ",\"longitude\":" << t.longitude
           << ",\"speedMps\":" << t.speedMps
           << ",\"timestampMs\":" << t.timestampMs
           << "}";
    }
    os << "]}";
    return os.str();
}

extern "C" {

JNIEXPORT void JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_initializeEngine(JNIEnv*, jobject) {
    if (!g_engine) {
        g_engine = std::make_unique<geo_engine::GeoEngine>();
    }
}

JNIEXPORT void JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_addZone(JNIEnv* env, jobject,
                                                     jstring id, jstring name,
                                                     jdouble latitude, jdouble longitude,
                                                     jdouble radiusMeters) {
    if (!g_engine) return;
    const char* cId   = env->GetStringUTFChars(id,   nullptr);
    const char* cName = env->GetStringUTFChars(name, nullptr);
    geo_engine::GeofenceZone zone(cId, cName, latitude, longitude, radiusMeters);
    g_engine->addZone(zone);
    env->ReleaseStringUTFChars(id,   cId);
    env->ReleaseStringUTFChars(name, cName);
}

JNIEXPORT void JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_removeZoneById(JNIEnv* env, jobject,
                                                            jstring id) {
    if (!g_engine) return;
    const char* cId = env->GetStringUTFChars(id, nullptr);
    g_engine->removeZone(cId);
    env->ReleaseStringUTFChars(id, cId);
}

// Returns JSON string: {"isInsideAny":0,"nextIntervalMs":10000,"distanceMeters":500,"transitions":[...]}
JNIEXPORT jstring JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_processLocation(JNIEnv* env, jobject,
                                                             jdouble latitude, jdouble longitude,
                                                             jdouble speedMps,
                                                             jdouble accuracyMeters,
                                                             jlong   timestampMs) {
    std::string json = "{\"isInsideAny\":0,\"nextIntervalMs\":60000,\"distanceMeters\":0,\"transitions\":[]}";
    if (g_engine) {
        geo_engine::UserLocation loc(latitude, longitude, speedMps,
                                     accuracyMeters, (int64_t)timestampMs);
        geo_engine::EngineResponse response = g_engine->processLocation(loc);
        json = responseToJson(response);
    }
    return env->NewStringUTF(json.c_str());
}

JNIEXPORT jboolean JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_appendHistoryRoutePoint(
    JNIEnv* env,
    jobject thiz,
    jstring directory,
    jstring dayKey,
    jlong timestampMs,
    jdouble latitude,
    jdouble longitude,
    jdouble speedMps,
    jdouble minDistanceMeters,
    jlong minIntervalMs
) {
    const geo_engine::HistoryRoutePoint point(
        static_cast<int64_t>(timestampMs),
        latitude,
        longitude,
        speedMps
    );
    return static_cast<jboolean>(
        g_history_engine.appendRoutePoint(
            stringFromJString(env, directory),
            stringFromJString(env, dayKey),
            point,
            minDistanceMeters,
            static_cast<int64_t>(minIntervalMs)
        )
    );
}

JNIEXPORT jboolean JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_appendHistoryAlertEvent(
    JNIEnv* env,
    jobject thiz,
    jstring directory,
    jstring dayKey,
    jstring id,
    jlong timestampMs,
    jstring alertId,
    jstring task,
    jstring place,
    jstring address,
    jstring eventType,
    jdouble latitude,
    jdouble longitude
) {
    geo_engine::HistoryAlertEvent event;
    event.id = stringFromJString(env, id);
    event.timestampMs = static_cast<int64_t>(timestampMs);
    event.alertId = stringFromJString(env, alertId);
    event.task = stringFromJString(env, task);
    event.place = stringFromJString(env, place);
    event.address = stringFromJString(env, address);
    event.eventType = stringFromJString(env, eventType);
    event.latitude = latitude;
    event.longitude = longitude;

    return static_cast<jboolean>(
        g_history_engine.appendAlertEvent(
            stringFromJString(env, directory),
            stringFromJString(env, dayKey),
            event
        )
    );
}

JNIEXPORT jstring JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_loadHistoryDayJson(
    JNIEnv* env,
    jobject thiz,
    jstring directory,
    jstring dayKey
) {
    const std::string json = g_history_engine.loadDayJson(
        stringFromJString(env, directory),
        stringFromJString(env, dayKey)
    );
    return env->NewStringUTF(json.c_str());
}

JNIEXPORT jstring JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_listHistoryDaySummariesJson(
    JNIEnv* env,
    jobject thiz,
    jstring directory
) {
    const auto summaries = g_history_engine.listDaySummaries(stringFromJString(env, directory));
    std::ostringstream out;
    out << "[";
    for (size_t i = 0; i < summaries.size(); ++i) {
        if (i > 0) {
            out << ",";
        }
        const auto& summary = summaries[i];
        out << "{";
        out << "\"dayKey\":\"" << escapeJsonString(summary.dayKey) << "\",";
        out << "\"startTimestampMs\":" << summary.startTimestampMs << ",";
        out << "\"endTimestampMs\":" << summary.endTimestampMs << ",";
        out << "\"pointCount\":" << summary.pointCount << ",";
        out << "\"alertEventCount\":" << summary.alertEventCount << ",";
        out << "\"distanceMeters\":" << summary.distanceMeters;
        out << "}";
    }
    out << "]";
    const std::string json = out.str();
    return env->NewStringUTF(json.c_str());
}

JNIEXPORT jint JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_pruneHistoryBeforeDay(
    JNIEnv* env,
    jobject thiz,
    jstring directory,
    jstring minimumDayKey
) {
    return static_cast<jint>(
        g_history_engine.pruneBeforeDay(
            stringFromJString(env, directory),
            stringFromJString(env, minimumDayKey)
        )
    );
}

/**
 * JNI function: Clear all zones
 */
JNIEXPORT void JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_clearZones(JNIEnv*, jobject) {
    if (g_engine) g_engine->clearZones();
}

JNIEXPORT jint JNICALL
Java_com_placealertme_geofence_GeoEngineJNI_getZoneCount(JNIEnv*, jobject) {
    if (g_engine) return (jint)g_engine->getZoneCount();
    return 0;
}

}  // extern "C"
