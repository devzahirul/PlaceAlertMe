#include <jni.h>
#include "geo_engine.h"
#include "history_engine.h"
#include <algorithm>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

// Global engine instance
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

static jobject makeTransition(JNIEnv* env,
                              const geo_engine::ZoneTransition& transition,
                              const char* className) {
    jclass transitionClass = env->FindClass(className);
    jmethodID transitionCtor = env->GetMethodID(
        transitionClass,
        "<init>",
        "(Ljava/lang/String;ZDI)V"
    );
    jstring zoneId = env->NewStringUTF(transition.zoneId.c_str());
    jobject result = env->NewObject(
        transitionClass,
        transitionCtor,
        zoneId,
        static_cast<jboolean>(transition.isInside),
        static_cast<jdouble>(transition.distanceMeters),
        static_cast<jint>(transition.zoneIndex)
    );
    env->DeleteLocalRef(zoneId);
    return result;
}

static jobject makeTransitionList(JNIEnv* env,
                                  const std::vector<geo_engine::ZoneTransition>& transitions,
                                  const char* transitionClassName) {
    jclass arrayListClass = env->FindClass("java/util/ArrayList");
    jmethodID arrayListCtor = env->GetMethodID(arrayListClass, "<init>", "()V");
    jmethodID addMethod = env->GetMethodID(arrayListClass, "add", "(Ljava/lang/Object;)Z");
    jobject list = env->NewObject(arrayListClass, arrayListCtor);

    for (const auto& transition : transitions) {
        jobject transitionObject = makeTransition(env, transition, transitionClassName);
        env->CallBooleanMethod(list, addMethod, transitionObject);
        env->DeleteLocalRef(transitionObject);
    }

    return list;
}

static jobject makeEngineResponse(JNIEnv* env,
                                  const geo_engine::EngineResponse& response,
                                  const char* responseClassName,
                                  const char* transitionClassName) {
    jclass responseClass = env->FindClass(responseClassName);
    jmethodID responseCtor = env->GetMethodID(
        responseClass,
        "<init>",
        "(ZJDLjava/util/List;)V"
    );
    jobject transitions = makeTransitionList(env, response.transitions, transitionClassName);
    jobject result = env->NewObject(
        responseClass,
        responseCtor,
        static_cast<jboolean>(response.isInsideZone),
        static_cast<jlong>(response.nextIntervalMs),
        static_cast<jdouble>(response.distanceMeters),
        transitions
    );
    env->DeleteLocalRef(transitions);
    return result;
}

static jobject makeNearestList(JNIEnv* env,
                               const std::vector<geo_engine::NearestZone>& nearest,
                               const char* nearestClassName) {
    jclass arrayListClass = env->FindClass("java/util/ArrayList");
    jmethodID arrayListCtor = env->GetMethodID(arrayListClass, "<init>", "()V");
    jmethodID addMethod = env->GetMethodID(arrayListClass, "add", "(Ljava/lang/Object;)Z");
    jobject list = env->NewObject(arrayListClass, arrayListCtor);

    jclass nearestClass = env->FindClass(nearestClassName);
    jmethodID nearestCtor = env->GetMethodID(
        nearestClass,
        "<init>",
        "(Ljava/lang/String;ID)V"
    );

    for (const auto& zone : nearest) {
        jstring zoneId = env->NewStringUTF(zone.zoneId.c_str());
        jobject zoneObject = env->NewObject(
            nearestClass,
            nearestCtor,
            zoneId,
            static_cast<jint>(zone.zoneIndex),
            static_cast<jdouble>(zone.distanceMeters)
        );
        env->CallBooleanMethod(list, addMethod, zoneObject);
        env->DeleteLocalRef(zoneObject);
        env->DeleteLocalRef(zoneId);
    }

    return list;
}

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

JNIEXPORT void JNICALL
Java_com_placealertme_core_GeoEngineJNI_addZoneWithId(JNIEnv* env, jobject thiz,
                                                       jstring zoneId,
                                                       jdouble latitude,
                                                       jdouble longitude,
                                                       jdouble radiusMeters,
                                                       jboolean notifyOnEntry,
                                                       jboolean notifyOnExit) {
    if (g_engine) {
        const char* rawZoneId = env->GetStringUTFChars(zoneId, nullptr);
        geo_engine::GeofenceZone zone(
            rawZoneId ? std::string(rawZoneId) : std::string(),
            latitude,
            longitude,
            radiusMeters,
            notifyOnEntry,
            notifyOnExit
        );
        g_engine->addZone(zone);
        if (rawZoneId) {
            env->ReleaseStringUTFChars(zoneId, rawZoneId);
        }
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

JNIEXPORT jobject JNICALL
Java_com_placealertme_core_GeoEngineJNI_processLocationDetailed(JNIEnv* env, jobject thiz,
                                                                 jdouble latitude,
                                                                 jdouble longitude,
                                                                 jdouble speedMps) {
    geo_engine::EngineResponse response;

    if (g_engine) {
        geo_engine::UserLocation location(latitude, longitude, speedMps);
        response = g_engine->processLocation(location);
    }

    return makeEngineResponse(
        env,
        response,
        "com/placealertme/core/GeoEngineJNI$EngineResponse",
        "com/placealertme/core/GeoEngineJNI$ZoneTransition"
    );
}

JNIEXPORT jobject JNICALL
Java_com_placealertme_core_GeoEngineJNI_updateZoneState(JNIEnv* env, jobject thiz,
                                                         jstring zoneId,
                                                         jboolean isInside) {
    if (!g_engine) {
        return nullptr;
    }

    const char* rawZoneId = env->GetStringUTFChars(zoneId, nullptr);
    geo_engine::ZoneTransition transition;
    const bool shouldNotify = g_engine->updateZoneState(
        rawZoneId ? std::string(rawZoneId) : std::string(),
        isInside,
        transition
    );
    if (rawZoneId) {
        env->ReleaseStringUTFChars(zoneId, rawZoneId);
    }

    if (!shouldNotify) {
        return nullptr;
    }

    return makeTransition(
        env,
        transition,
        "com/placealertme/core/GeoEngineJNI$ZoneTransition"
    );
}

JNIEXPORT jobject JNICALL
Java_com_placealertme_core_GeoEngineJNI_nearestZones(JNIEnv* env, jobject thiz,
                                                      jdouble latitude,
                                                      jdouble longitude,
                                                      jint maxCount) {
    if (!g_engine || maxCount <= 0) {
        std::vector<geo_engine::NearestZone> empty;
        return makeNearestList(
            env,
            empty,
            "com/placealertme/core/GeoEngineJNI$NearestZone"
        );
    }

    const auto nearest = g_engine->nearestZones(
        latitude,
        longitude,
        static_cast<size_t>(maxCount)
    );
    return makeNearestList(
        env,
        nearest,
        "com/placealertme/core/GeoEngineJNI$NearestZone"
    );
}

JNIEXPORT jboolean JNICALL
Java_com_placealertme_core_GeoEngineJNI_appendHistoryRoutePoint(
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
Java_com_placealertme_core_GeoEngineJNI_appendHistoryAlertEvent(
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
Java_com_placealertme_core_GeoEngineJNI_loadHistoryDayJson(
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
Java_com_placealertme_core_GeoEngineJNI_listHistoryDaySummariesJson(
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
Java_com_placealertme_core_GeoEngineJNI_pruneHistoryBeforeDay(
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

JNIEXPORT jboolean JNICALL
Java_com_placealertme_core_GeoEngineJNI_hasMovedSignificantly(JNIEnv* env, jobject thiz,
                                                               jdouble fromLatitude,
                                                               jdouble fromLongitude,
                                                               jdouble toLatitude,
                                                               jdouble toLongitude,
                                                               jdouble thresholdMeters) {
    if (!g_engine) {
        return JNI_TRUE;
    }
    return g_engine->hasMovedSignificantly(
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
        thresholdMeters
    );
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
