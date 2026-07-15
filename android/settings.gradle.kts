// Force Android SDK root for ALL projects (checked first by AGP's
// SdkDirectoryProperty before local.properties and env vars). Plugin
// subprojects from pub cache declare their own AGP version in buildscript
// blocks; setting this at the settings level guarantees it's available to
// every subproject before its build.gradle is evaluated.
gradle.startParameter.projectProperties["android.sdkDirectory"] =
    System.getenv("ANDROID_SDK_ROOT") ?: "/usr/local/lib/android/sdk"

pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
