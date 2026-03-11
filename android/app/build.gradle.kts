plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shong.voxoverlay_translator"

    // API 36 (Android 16) is the current standard for 2026.
    compileSdk = 36
    ndkVersion = "29.0.14206865"
    defaultConfig {
        applicationId = "com.shong.voxoverlay_translator"

        // MANDATORY: Internal Audio Capture (MediaProjection) requires API 29+.
        // 'flutter.minSdkVersion' is often 16 or 21 by default.
        minSdk = 29
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }
    compileOptions {
        // Modernized to Java 17 (Required by latest Gradle/AGP in 2026)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required for the Foreground Service and Notification support used in your bridge
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
}