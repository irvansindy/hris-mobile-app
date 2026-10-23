import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(",")?.filter { it.isNotEmpty() }?.associate {
        val decoded = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
        val separator = decoded.indexOf('=')
        require(separator > 0) { "Invalid dart-define." }
        decoded.substring(0, separator) to decoded.substring(separator + 1)
    } ?: emptyMap()
val firebaseDevelopment = dartDefines["PUSH_MODE"]?.trim()?.lowercase() == "firebase" &&
    dartDefines["DEMO_MODE"] != "true"

if (firebaseDevelopment) {
    require((dartDefines["APP_ENV"] ?: "development").trim().lowercase() == "development") {
        "Personal Firebase configuration is development-only."
    }
    require(gradle.startParameter.taskNames.none {
        it.contains("release", ignoreCase = true) || it.contains("profile", ignoreCase = true)
    }) { "Personal Firebase configuration is debug-only." }
    require(file("src/debug/google-services.json").isFile) {
        "Firebase development requires android/app/src/debug/google-services.json."
    }
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.hrm_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.hrm_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    constraints {
        listOf("debugImplementation", "profileImplementation").forEach { configuration ->
            add(configuration, "junit:junit:4.13.2") {
                because("GHSA-269g-pwp5-87pp affects integration_test's transitive JUnit 4.12")
            }
        }
    }
}

flutter {
    source = "../.."
}
