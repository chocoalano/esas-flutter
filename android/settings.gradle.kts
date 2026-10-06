pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 8.9.1 is the floor `camera_android_camerax` sets: it pulls
    // androidx.camera 1.6.0, which refuses to build on anything older. Gradle
    // 8.12 is already in the wrapper, which is above AGP 8.9.1's own floor of
    // 8.11.1, so nothing else has to move.
    id("com.android.application") version "8.9.1" apply false
    // 2.3 is the floor `firebase_auth` 6 sets: firebase-auth 24.2.0 ships
    // Kotlin 2.3 metadata, which a 2.1 compiler refuses to read. Still inside
    // what AGP 8.9.1 and Gradle 8.12 support, so neither has to move.
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
}

include(":app")
