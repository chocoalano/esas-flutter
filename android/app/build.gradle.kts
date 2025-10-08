import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    try {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } catch (e: Exception) {
        println("Warning: Could not load key.properties file. Signing will default or fail. Error: ${e.message}")
    }
} else {
    println("Warning: key.properties file not found. Ensure it exists in the project root for release signing.")
}

dependencies {
  implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
  implementation("com.google.firebase:firebase-analytics")
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

android {
    namespace = "com.example.esas"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.esas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Correct way to configure the existing 'debug' signing config
        getByName("debug") { // <--- FIX: Access the existing 'debug' signing config
            // You typically don't need to explicitly set these if you use the default debug keystore
            // storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")
            // storePassword = "android"
            // keyAlias = "androiddebugkey"
            // keyPassword = "android"
            // If you ARE customizing the debug keystore, uncomment and set the above lines.
            // Otherwise, leave this block empty or remove it if no customization is needed.
        }

        create("release") {
            storeFile = keystoreProperties["storeFile"]?.let { file(it.toString()) }
                ?: error("Missing 'storeFile' in key.properties for release signing.")
            storePassword = keystoreProperties["storePassword"]?.toString()
                ?: error("Missing 'storePassword' in key.properties for release signing.")
            keyAlias = keystoreProperties["keyAlias"]?.toString()
                ?: error("Missing 'keyAlias' in key.properties for release signing.")
            keyPassword = keystoreProperties["keyPassword"]?.toString()
                ?: error("Missing 'keyPassword' in key.properties for release signing.")
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
apply(plugin = "com.google.gms.google-services")