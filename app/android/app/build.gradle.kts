plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.consentlink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.consentlink"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 23 (Android 6): flutter_secure_storage keeps the database key in the Keystore.
        // 26: the llama.cpp AAR (libs/llama-cpp-dart.aar) needs Android 8.0+.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // llama.cpp for the on-device LLM (app/lib/ai/llm), arm64-v8a only.
    // From github.com/netdur/llama_cpp_dart release v0.9.0-dev.10 (MIT),
    // sha256 51b5f4624e10296e362725a056ed0e3609c71f00ce4575ce28b28f8ec9aafcf7.
    implementation(files("libs/llama-cpp-dart.aar"))
}
