cmake_minimum_required(VERSION 3.14)
project(GeoEngine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Library target
add_library(geo_engine STATIC
    geo_engine.cpp
)

target_include_directories(geo_engine
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

# Tests (enabled by default, disable with -DBUILD_TESTS=OFF)
option(BUILD_TESTS "Build unit tests" ON)

if(BUILD_TESTS)
    enable_testing()

    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG        v1.14.0
    )
    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(googletest)

    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/geo_engine_test.cpp")
        add_executable(geo_engine_tests
            tests/geo_engine_test.cpp
        )
        target_include_directories(geo_engine_tests PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/include
        )
        target_link_libraries(geo_engine_tests
            PRIVATE geo_engine GTest::gtest_main
        )
        include(GoogleTest)
        gtest_discover_tests(geo_engine_tests)
    endif()
endif()

install(TARGETS geo_engine EXPORT GeoEngineTargets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)
install(DIRECTORY include/ DESTINATION include)
