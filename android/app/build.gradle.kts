import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keystore rilis opsional: android/key.properties (jangan di-commit).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Batasi ABI yang dipaketkan persis sesuai --target-platform milik Flutter.
// Tanpa ini, pustaka plugin (mis. JNA/DataStore) tetap menyertakan .so arm64-v8a
// sehingga APK mengklaim mendukung arm64 padahal libflutter.so/libapp.so
// untuk arm64 tidak ada -> crash (UnsatisfiedLinkError) di HP ARM64.
val flutterTargetPlatforms: String =
    (project.findProperty("target-platform") as String?) ?: "android-arm,android-arm64,android-x64"

val packagedAbis: List<String> = flutterTargetPlatforms
    .split(",")
    .mapNotNull { platform ->
        when (platform.trim()) {
            "android-arm" -> "armeabi-v7a"
            "android-arm64" -> "arm64-v8a"
            "android-x64" -> "x86_64"
            else -> null
        }
    }
    .distinct()

// Saat build memakai --split-per-abi, Gradle sudah membuat satu APK per ABI sehingga
// ndk.abiFilters manual akan bentrok ("Conflicting configuration ... abiFilters").
// Pada mode split, ABI ditangani oleh Flutter, jadi lewati saja.
val isSplitPerAbi: Boolean = (project.findProperty("split-per-abi") as String?)?.toBoolean() ?: false

logger.lifecycle("[kas] target-platform='$flutterTargetPlatforms' -> abiFilters=$packagedAbis, splitPerAbi=$isSplitPerAbi")
if (!hasReleaseKeystore) {
    logger.lifecycle(
        "[kas] PERINGATAN: android/key.properties tidak ditemukan. " +
            "Build release akan ditandatangani dengan debug key (hanya untuk uji, JANGAN untuk Play Store)."
    )
}

android {
    namespace = "com.bintangnusantara.kas"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.bintangnusantara.kas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        if (!isSplitPerAbi) {
            ndk {
                abiFilters += packagedAbis
            }
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // Path storeFile dihitung relatif terhadap folder android/
                // (tempat key.properties berada), bukan folder android/app.
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                // Tanda tangan v1+v2+v3 sekaligus. Sebagian ROM Android
                // (khususnya OEM lama/China) menolak instalasi bila hanya
                // memakai v2 atau v3 saja, sehingga v1 tetap diaktifkan.
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            // Pakai keystore rilis bila android/key.properties tersedia.
            // Tanpa file tersebut, build tetap jalan memakai debug key
            // (cukup untuk instalasi uji, TIDAK untuk Play Store).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
