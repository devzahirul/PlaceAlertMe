#include <jni.h>
#include "geo_engine.h"
#include <algorithm>
#include <memory>
#include <string>
#include <sstream>

static std::unique_ptr<geo_engine::GeoEngine> g_engine = nullptr;

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
