plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shong.voxoverlay_translator"

    // API 36 (Android 16) is the current standard.
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    defaultConfig {
        applicationId = "com.shong.voxoverlay_translator"

        minSdk = 24
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // Added x86_64 so you can test on PC Android Emulators.
            // It will be automatically stripped out by Google Play when you publish.
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }

        // --- CRITICAL: Pass arguments to CMake ---
        externalNativeBuild {
            cmake {
                // Force Release build for the C++ code to guarantee fast inference speed
                arguments += listOf("-DCMAKE_BUILD_TYPE=Release")
                // Explicitly tell the NDK to use NEON instructions for ARM
                arguments += listOf("-DANDROID_ARM_NEON=ON")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}

flutter {
    source = "../.."
}