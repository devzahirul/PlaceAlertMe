cmake_minimum_required(VERSION 3.18)
project(geo_engine_android)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT MSVC)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -Wextra")
endif()

# Core geofencing engine library
add_library(geo_engine_core STATIC
    ../../cpp/geo_engine/geo_engine.cpp
    ../../cpp/geo_engine/include/geo_engine.h
)

target_include_directories(geo_engine_core PUBLIC
    ../../cpp/geo_engine/include
)

# Android JNI wrapper
add_library(geo_engine_jni SHARED
    src/main/cpp/geo_engine_jni.cpp
)

target_include_directories(geo_engine_jni PRIVATE
    ../../cpp/geo_engine/include
)

target_link_libraries(geo_engine_jni PRIVATE
    geo_engine_core
)

# Enable ARM NEON optimization if available
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    target_compile_options(geo_engine_jni PRIVATE -mfpu=neon)
endif()
