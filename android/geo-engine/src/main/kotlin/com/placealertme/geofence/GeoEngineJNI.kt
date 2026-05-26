package com.placealertme.geofence

import org.json.JSONObject
import org.json.JSONArray

object GeoEngineJNI {
    init {
        System.loadLibrary("geo_engine_jni")
    }

    external fun initializeEngine()

    external fun addZone(
        id: String, name: String,
        latitude: Double, longitude: Double, radiusMeters: Double
    )

    external fun removeZoneById(id: String)

    // Returns JSON string from C++
    external fun processLocation(
        latitude: Double, longitude: Double, speedMps: Double,
        accuracyMeters: Double, timestampMs: Long
    ): String

    external fun clearZones()
    external fun getZoneCount(): Int

    data class ZoneTransition(
        val zoneId: String,
        val zoneName: String,
        val type: String,        // "ENTER" or "EXIT"
        val distanceMeters: Double,
        val latitude: Double,
        val longitude: Double,
        val speedMps: Double,
        val timestampMs: Long
    )

    data class EngineResponse(
        val isInsideAnyZone: Boolean,
        val nextIntervalMs: Long,
        val distanceToNearestMeters: Double,
        val transitions: List<ZoneTransition>
    )

    fun processLocationWrapped(
        latitude: Double, longitude: Double, speedMps: Double,
        accuracyMeters: Double, timestampMs: Long
    ): EngineResponse {
        val json = processLocation(latitude, longitude, speedMps, accuracyMeters, timestampMs)
        return parseEngineResponse(json)
    }

    private fun parseEngineResponse(json: String): EngineResponse {
        val obj = JSONObject(json)
        val transitions = mutableListOf<ZoneTransition>()
        val arr: JSONArray = obj.optJSONArray("transitions") ?: JSONArray()
        for (i in 0 until arr.length()) {
            val t = arr.getJSONObject(i)
            transitions.add(ZoneTransition(
                zoneId        = t.getString("zoneId"),
                zoneName      = t.getString("zoneName"),
                type          = t.getString("type"),
                distanceMeters = t.getDouble("distanceMeters"),
                latitude      = t.getDouble("latitude"),
                longitude     = t.getDouble("longitude"),
                speedMps      = t.getDouble("speedMps"),
                timestampMs   = t.getLong("timestampMs")
            ))
        }
        return EngineResponse(
            isInsideAnyZone        = obj.getInt("isInsideAny") != 0,
            nextIntervalMs         = obj.getLong("nextIntervalMs"),
            distanceToNearestMeters = obj.getDouble("distanceMeters"),
            transitions            = transitions
        )
    }
}
