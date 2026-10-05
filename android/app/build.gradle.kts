import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, if this machine has them.
//
// `key.properties` is deliberately not in the repository — it names a keystore
// and carries its passwords. A checkout without it must still be able to build
// and run in debug: that is what every developer, every CI check and every
// `flutter run` does, and none of them sign anything.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// Every value a release needs, and the file that would hold them. Missing any
// one of them means this machine cannot sign a release — which is a fact, not
// yet a failure. The failure is raised below, when a release is actually asked
// for.
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = releaseSigningKeys.filter { keystoreProperties[it] == null }
val canSignRelease = missingSigningKeys.isEmpty()

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
        // The debug config AGP already defines is used as-is: the shared debug
        // keystore is what makes a build installable on any developer's device
        // without configuring anything.

        // Created only when this machine can actually fill it in. The previous
        // version called `error()` here, and `signingConfigs {}` is evaluated
        // during Gradle's *configuration* phase — which runs for every task,
        // `assembleDebug` included. A checkout without `key.properties` could
        // therefore not be run at all, and the message it failed with talked
        // about release signing while somebody was pressing Run.
        if (canSignRelease) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"].toString())
                storePassword = keystoreProperties["storePassword"].toString()
                keyAlias = keystoreProperties["keyAlias"].toString()
                keyPassword = keystoreProperties["keyPassword"].toString()
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Null on a machine with no credentials. The release tasks refuse to
            // run in that case — see the guard below — so this never produces an
            // unsigned APK; it only stops debug builds from paying for it.
            signingConfig = signingConfigs.findByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Refuse a release build that would go out unsigned, at the moment one is asked
// for rather than at every invocation.
//
// This is the check the configuration-time `error()` was trying to be. Same
// protection, without holding debug hostage to it: an unsigned release is the
// thing that must never ship, and a developer pressing Run is not shipping.
tasks.matching { it.name.startsWith("assembleRelease") || it.name.startsWith("bundleRelease") }
    .configureEach {
        doFirst {
            if (!canSignRelease) {
                throw GradleException(
                    buildString {
                        append("Tidak dapat menandatangani rilis. ")
                        if (!keystorePropertiesFile.exists()) {
                            append("Berkas ${keystorePropertiesFile.path} tidak ada.")
                        } else {
                            append("Kunci berikut belum ada di key.properties: ")
                            append(missingSigningKeys.joinToString(", "))
                            append(".")
                        }
                        append(
                            " Isi storeFile, storePassword, keyAlias dan keyPassword," +
                                " lalu ulangi. Build debug tidak memerlukannya."
                        )
                    }
                )
            }
        }
    }

flutter {
    source = "../.."
}
apply(plugin = "com.google.gms.google-services")