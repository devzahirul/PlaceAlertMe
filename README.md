# PlaceAlertMe - Custom Geofencing Application

A highly optimized, battery-efficient cross-platform geofencing application for Android (Kotlin) and iOS (Swift) using a shared C++ Core Engine.

## Architecture Overview

### Core Components
1. **C++ Core Engine** - Pure C++17 library for geofence calculations and adaptive tracking
2. **Android Layer** - Kotlin with JNI integration for C++ core
3. **iOS Layer** - Swift with C-Interop for C++ core

### Key Features
- Custom geofencing without native Google/iOS APIs
- Battery-efficient adaptive tracking frequencies
- Speed and distance-based interval adjustment
- Activity recognition integration (pause when still)
- Background location updates

## Project Structure

```
PlaceAlertMe/
├── cpp/
│   └── geo_engine/          # C++ Core Engine
├── android/
│   ├── app/                 # Kotlin Android App
│   ├── gradle/              # Gradle configs
│   └── jni/                 # JNI bindings
├── ios/
│   ├── PlaceAlertMe/        # Swift iOS App
│   └── CppInterop/          # C++ Interop bridge
└── docs/
    └── ARCHITECTURE.md      # Detailed architecture
```

## Build Instructions

See individual platform documentation in their respective directories.
