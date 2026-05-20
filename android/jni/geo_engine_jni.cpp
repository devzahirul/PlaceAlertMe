#include <jni.h>
#include "geo_engine.h"
#include <memory>

// Global engine instance
static std::unique_ptr<geo_engine::GeoEngine> g_engine = nullptr;

extern "C" {

/**
 * JNI function: Initialize the geofencing engine
 */
JNIEXPORT void JNICALL
Java_com_placealertme_core_GeoEngineJNI_initializeEngine(JNIEnv* env, jobject thiz) {
    if (!g_engine) {
        g_engine = std::make_unique<geo_engine::GeoEngine>();
    }
}

/**
 * JNI function: Add a geofence zone
 */
JNIEXPORT void JNICALL
Java_com_placealertme_core_GeoEngineJNI_addZone(JNIEnv* env, jobject thiz,
                                                 jdouble latitude, jdouble longitude,
                                                 jdouble radiusMeters) {
    if (g_engine) {
        geo_engine::GeofenceZone zone(latitude, longitude, radiusMeters);
        g_engine->addZone(zone);
    }
}

/**
 * JNI function: Process location update
 * Returns: [isInsideZone (0/1), nextIntervalMs, distanceMeters]
 */
JNIEXPORT jlongArray JNICALL
Java_com_placealertme_core_GeoEngineJNI_processLocation(JNIEnv* env, jobject thiz,
                                                         jdouble latitude, jdouble longitude,
                                                         jdouble speedMps) {
    jlongArray result = env->NewLongArray(3);
    jlong values[3] = {0, 60000, 0};

    if (g_engine) {
        geo_engine::UserLocation location(latitude, longitude, speedMps);
        geo_engine::EngineResponse response = g_engine->processLocation(location);

        values[0] = response.isInsideZone ? 1 : 0;
        values[1] = response.nextIntervalMs;
        values[2] = (jlong)response.distanceMeters;
    }

    env->SetLongArrayRegion(result, 0, 3, values);
    return result;
}

/**
 * JNI function: Clear all zones
 */
JNIEXPORT void JNICALL
Java_com_placealertme_core_GeoEngineJNI_clearZones(JNIEnv* env, jobject thiz) {
    if (g_engine) {
        g_engine->clearZones();
    }
}

/**
 * JNI function: Get zone count
 */
JNIEXPORT jint JNICALL
Java_com_placealertme_core_GeoEngineJNI_getZoneCount(JNIEnv* env, jobject thiz) {
    if (g_engine) {
        return (jint)g_engine->getZoneCount();
    }
    return 0;
}

}  // extern "C"
