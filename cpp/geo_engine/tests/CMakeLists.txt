cmake_minimum_required(VERSION 3.18)
project(geo_engine_tests)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Google Test
find_package(GTest REQUIRED)

# Include the geo_engine header
include_directories(${CMAKE_SOURCE_DIR}/../include)

# Add the geo_engine library
add_library(geo_engine_lib STATIC
    ${CMAKE_SOURCE_DIR}/../geo_engine.cpp
    ${CMAKE_SOURCE_DIR}/../history_engine.cpp
    ${CMAKE_SOURCE_DIR}/../include/geo_engine.h
    ${CMAKE_SOURCE_DIR}/../include/history_engine.h
)

target_include_directories(geo_engine_lib PUBLIC
    ${CMAKE_SOURCE_DIR}/../include
)

# Add test executable
add_executable(geo_engine_test geo_engine_test.cpp)

# Link against geo_engine and Google Test
target_link_libraries(geo_engine_test
    geo_engine_lib
    GTest::GTest
    GTest::Main
)

# Enable testing
enable_testing()
add_test(NAME GeoEngineTests COMMAND geo_engine_test)
