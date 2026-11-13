import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

// Release signing credentials, if this machine has them.
//
// `key.properties` is deliberately not in the repository — it names a keystore
// and carries its passwords. A checkout without it must still be able to build
// and run in debug: that is what every developer, every CI check and every
// `flutter run` does, and none of them sign anything.
//
// Each value can also come from an ABSENSAS_SIGNING_* environment variable,
// which wins over the file, so the passwords need not sit in any file - e.g.
// read from the macOS Keychain for one build (see key.properties.example):
//
//   ABSENSAS_SIGNING_STORE_PASSWORD="$(security find-generic-password -s absensas-signing-store -w)" \
//   ABSENSAS_SIGNING_KEY_PASSWORD="$(security find-generic-password -s absensas-signing-key -w)" \
//   flutter build apk --release
//
// No value is ever logged.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// key.properties name -> the environment variable that overrides it.
val signingEnvironment = mapOf(
    "storeFile" to "ABSENSAS_SIGNING_STORE_FILE",
    "storePassword" to "ABSENSAS_SIGNING_STORE_PASSWORD",
    "keyAlias" to "ABSENSAS_SIGNING_KEY_ALIAS",
    "keyPassword" to "ABSENSAS_SIGNING_KEY_PASSWORD",
    "storeType" to "ABSENSAS_SIGNING_STORE_TYPE",
)

// A blank value counts as absent, so an empty variable falls back to the file.
val signingFromEnvironment = signingEnvironment.mapValues { (_, variable) ->
    providers.environmentVariable(variable).orNull?.takeIf { it.isNotBlank() }
}
val signing: Map<String, String> = signingEnvironment.keys.mapNotNull { key ->
    (signingFromEnvironment[key] ?: keystoreProperties.getProperty(key)?.takeIf { it.isNotBlank() })
        ?.let { key to it }
}.toMap()

// Every value a release needs, and the file that would hold them. Missing any
// one of them means this machine cannot sign a release — which is a fact, not
// yet a failure. The failure is raised below, when a release is actually asked
// for.
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = releaseSigningKeys.filter { signing[it] == null }
val canSignRelease = missingSigningKeys.isEmpty()

// A leading `~/` is the home directory, so neither the file nor a variable has
// to name a user's absolute path. A relative path resolves against android/app.
val releaseStoreFile: File? = signing["storeFile"]?.let { path ->
    file(if (path.startsWith("~/")) System.getProperty("user.home") + path.substring(1) else path)
}
val releaseStoreFileSource =
    if (signingFromEnvironment["storeFile"] != null) "ABSENSAS_SIGNING_STORE_FILE" else "key.properties"

// PKCS12 when stated (storeType) or when the file is a .p12/.pfx; otherwise the
// JDK default, which reads PKCS12 and JKS keystores alike.
val releaseStoreType: String? = signing["storeType"]
    ?: releaseStoreFile?.name?.lowercase()
        ?.takeIf { it.endsWith(".p12") || it.endsWith(".pfx") }
        ?.let { "PKCS12" }

// Keystores that must never sign com.absensas.app again, by file name: the 2025
// key that is still in Git history, and the upload key retired by the PO
// (2026-11-13, docs: tenancy-app mobile-release-identity-and-signing.md §13).
// Names can be added - never removed - with
// `-Pabsensas.retiredSigningStores=a.jks,b.jks` or in gradle.properties.
val retiredSigningStores: Set<String> =
    (listOf("upload-keystore.jks", "esas-keystore.jks") +
        (providers.gradleProperty("absensas.retiredSigningStores").orNull ?: "").split(','))
        .map { it.trim().lowercase() }
        .filter { it.isNotEmpty() }
        .toSet()
val releaseUsesRetiredKey = releaseStoreFile?.name?.lowercase() in retiredSigningStores

dependencies {
  implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
  implementation("com.google.firebase:firebase-analytics")
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

android {
    namespace = "com.absensas.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.absensas.app"
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
                storeFile = releaseStoreFile
                storePassword = signing.getValue("storePassword")
                keyAlias = signing.getValue("keyAlias")
                keyPassword = signing.getValue("keyPassword")
                releaseStoreType?.let { storeType = it }
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

// Kotlin 2.3 turned `android { kotlinOptions { jvmTarget = ... } }` into a
// compile error; this is its replacement. Must match `compileOptions` above.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
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
                            append("Berkas ${keystorePropertiesFile.path} tidak ada. ")
                        }
                        append("Belum diisi: ")
                        append(missingSigningKeys.joinToString(", ") { "$it (${signingEnvironment.getValue(it)})" })
                        append(".")
                        append(
                            " Isi storeFile, storePassword, keyAlias dan keyPassword lewat variabel" +
                                " ABSENSAS_SIGNING_* atau key.properties, lalu ulangi." +
                                " Build debug tidak memerlukannya."
                        )
                    }
                )
            }
        }
    }

// Refuse to sign a release with a retired key - when the task graph is ready,
// before any task runs, so not even an intermediate signed APK/AAB is written
// (a doFirst on assembleRelease would run only after packageRelease had signed).
// Only a graph that would package, sign or install a release is refused:
// debug builds, `signingReport`, IDE sync and every other task are untouched.
val releaseSigningTask = Regex("^(assemble|bundle|package|sign|install|validateSigning)Release")

gradle.taskGraph.whenReady {
    if (releaseUsesRetiredKey && allTasks.any { it.project == project && releaseSigningTask.containsMatchIn(it.name) }) {
        throw GradleException(
            "legacy signing key is retired for com.absensas.app; configure ABSENSAS_SIGNING_* or key.properties " +
                "for the Absensas key. (Release store file '${releaseStoreFile?.name}', from " +
                "$releaseStoreFileSource, is on the retired list.)"
        )
    }
}

flutter {
    source = "../.."
}