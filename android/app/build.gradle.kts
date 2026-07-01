plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.leveladude.money_manager"
    // Manche Plugins (z. B. package_info_plus) verlangen compileSdk 36.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.leveladude.money_manager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signiert mit den Debug-Keys – persönliche/Sideload-Nutzung (kein Play Store).
            signingConfig = signingConfigs.getByName("debug")
            // R8/Code-Shrinking aus: das ML-Kit-Texterkennungs-Plugin referenziert
            // optionale Sprach-Recognizer (Chinesisch/Japanisch/…), die nicht mit
            // eingebunden sind; R8 bricht sonst mit "Missing classes" ab. Für eine
            // Sideload-APK ist die etwas größere Datei unkritisch.
            isMinifyEnabled = false
            isShrinkResources = false
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
