# Building Release APK for PlaceAlertMe Example App

Complete guide to build the release APK locally on your machine.

## Prerequisites

### Required Software
- **Android Studio** (latest version)
- **Android SDK** (API 34 or higher)
- **Android NDK** (25.1.8937393 or compatible)
- **Gradle** (8.0+)
- **Java** (JDK 11+)

### Install Android Studio
1. Download from [developer.android.com](https://developer.android.com/studio)
2. Install and follow setup wizard
3. Install required SDK components:
   - Android SDK Platform 34
   - NDK 25.1
   - CMake

### Set Environment Variables
```bash
# Add to ~/.bashrc or ~/.zshrc
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.1.8937393
```

**Then reload your shell:**
```bash
source ~/.bashrc  # or ~/.zshrc
```

## Building Steps

### 1. Clone/Download Repository
```bash
git clone https://github.com/devzahirul/PlaceAlertMe.git
cd PlaceAlertMe
```

### 2. Open in Android Studio (Recommended)
```bash
# From project root
android-studio . &
```

**Or manually:**
1. Launch Android Studio
2. File → Open → Select PlaceAlertMe directory
3. Wait for Gradle sync to complete

### 3. Build Release APK

**Option A: Android Studio GUI**
1. Navigate to: Build → Build Bundle(s)/APK(s) → Build APK(s)
2. Select `:example-app` module
3. Wait for build to complete
4. Output: `android/example-app/build/outputs/apk/release/example-app-release.apk`

**Option B: Command Line**

Create `gradlew` wrapper script:
```bash
cd PlaceAlertMe/android

# On Linux/Mac
touch gradlew
chmod +x gradlew

# Or download from another Android project:
# cp ../other-project/gradlew .
```

Then build:
```bash
./gradlew :example-app:assembleRelease
```

**Option C: Direct Gradle**
```bash
cd PlaceAlertMe/android
gradle :example-app:assembleRelease
```

### 4. Build Output

After successful build, APK will be at:
```
android/example-app/build/outputs/apk/release/example-app-release.apk
```

**File Details:**
- **Name:** example-app-release.apk
- **Size:** ~30-40 MB
- **Debuggable:** No
- **Optimized:** Yes (ProGuard)

## Troubleshooting

### Gradle Sync Issues
**Problem:** "Failed to sync Gradle"

**Solution:**
```bash
cd PlaceAlertMe/android
./gradlew clean
./gradlew sync
```

### Missing Android SDK
**Problem:** "Android SDK not found"

**Solution:**
1. Open Android Studio
2. Tools → SDK Manager
3. Install Android 34 SDK
4. Install NDK 25.1

### Build Fails with CMake Error
**Problem:** "CMake not found"

**Solution:**
```bash
# Update NDK and CMake
android-sdk update-ndk 25.1.8937393
android-sdk update-cmake 3.22.1
```

### Out of Memory During Build
**Problem:** "java.lang.OutOfMemoryError"

**Solution:**
```bash
# Increase gradle memory
echo "org.gradle.jvmargs=-Xmx4096m" >> ~/.gradle/gradle.properties

# Or for this project
echo "org.gradle.jvmargs=-Xmx4096m" >> PlaceAlertMe/android/gradle.properties
```

### Signing Issue
**Problem:** "Build fails on sign"

**Solution:** Release build uses debug key by default in development. For Play Store:

```bash
# Create signing key
keytool -genkey -v -keystore my-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias my-key-alias

# Sign with custom key (edit build.gradle first)
```

## Installation on Device

### Via Android Studio
1. Connect device via USB
2. Build → Select Device
3. Run (Shift+F10)

### Via Command Line
```bash
# List connected devices
adb devices

# Install APK
adb install android/example-app/build/outputs/apk/release/example-app-release.apk

# Or reinstall (replace existing)
adb install -r android/example-app/build/outputs/apk/release/example-app-release.apk
```

### Manual Installation
1. Transfer APK to device
2. Open file manager
3. Tap APK file
4. Follow installation prompts

## Verification

### Check Build Success
```bash
ls -lh android/example-app/build/outputs/apk/release/
```

Expected output:
```
-rw-r--r-- example-app-release.apk (30-40 MB)
-rw-r--r-- output-metadata.json
```

### Verify App Installation
```bash
adb shell pm list packages | grep placealertme

# Should output:
# com.placealertme.example
```

### Check App Version
```bash
adb shell dumpsys package com.placealertme.example | grep versionName
```

## Build Variants

### Debug Build
```bash
./gradlew :example-app:assembleDebug
```
- **Size:** Smaller (~25 MB)
- **Speed:** Faster to build
- **Debugging:** Full symbols, logs enabled
- **Use:** Development and testing

### Release Build
```bash
./gradlew :example-app:assembleRelease
```
- **Size:** Larger (~35 MB), obfuscated
- **Speed:** Slower to build
- **Debugging:** Limited, optimized
- **Use:** Production deployment, Play Store

## Build Configuration

**File:** `android/example-app/build.gradle`

Key settings:
```gradle
defaultConfig {
    applicationId "com.placealertme.example"
    minSdk 24
    targetSdk 34
    versionCode 1
    versionName "1.0.0"
}
```

To customize:
1. Edit `build.gradle`
2. Change `versionCode` and `versionName`
3. Rebuild

## Play Store Submission

### Sign APK for Release
```bash
# Create keystore
keytool -genkey -v -keystore release.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias placealertme

# Verify signing
jarsigner -verify -verbose example-app-release.apk
```

### Generate Play Store Key
1. Follow [Google Play signing guide](https://developer.android.com/studio/publish/app-signing)
2. Create upload key
3. Register with Play Console

### Upload to Play Store
1. Create app on [Google Play Console](https://play.google.com/console)
2. Upload APK/AAB
3. Complete store listing
4. Submit for review

## Performance Tips

### Faster Builds
```bash
# Parallel compilation
org.gradle.parallel=true
org.gradle.workers.max=8

# Daemon
org.gradle.daemon=true

# Incremental compilation
android.enableSeparateApkRes=true
android.incremental=true
```

Add to `gradle.properties`:
```
org.gradle.jvmargs=-Xmx4096m
org.gradle.parallel=true
org.gradle.workers.max=8
org.gradle.daemon=true
```

### Clean Build
```bash
./gradlew clean
./gradlew :example-app:assembleRelease --build-cache
```

## CI/CD Build

### GitHub Actions
The repository includes automated build in `.github/workflows/build.yml`:
```yaml
- Run: ./gradlew assembleRelease
- Upload: Artifacts stored
- Release: Auto-generated on tags
```

Push tag to trigger:
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Local CI Simulation
```bash
# Full clean build
./gradlew clean :example-app:assembleRelease -x lint

# With tests
./gradlew clean :example-app:assembleRelease -x lint connectedAndroidTest

# With coverage
./gradlew clean :example-app:assembleRelease jacocoTestReport
```

## Testing Release APK

### Install and Test
```bash
# Install
adb install example-app-release.apk

# Grant permissions
adb shell pm grant com.placealertme.example android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.placealertme.example android.permission.ACCESS_BACKGROUND_LOCATION
adb shell pm grant com.placealertme.example android.permission.ACTIVITY_RECOGNITION

# Launch
adb shell am start -n com.placealertme.example/.MainActivity

# View logs
adb logcat | grep placealertme
```

## Size Optimization

### Check APK Size
```bash
# List contents
unzip -l example-app-release.apk | head -20

# Analyze with bundletool
bundletool analyze-bundle --bundle=example-app.aab --output=analysis.html
```

### Reduce Size
- Enable minification (ProGuard)
- Remove unused resources
- Use vector drawables
- Enable zipalign

## Support

- See [README.md](README.md) for app usage
- See [ANDROID_LIBRARY_USAGE.md](../../ANDROID_LIBRARY_USAGE.md) for integration
- See [BUILD.md](../../BUILD.md) for build details

---

**Status:** ✅ Ready to Build  
**Last Updated:** 2024-05-20
