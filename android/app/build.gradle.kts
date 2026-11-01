import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

// Treat the template placeholders as "not configured" instead of trying to
// sign with them, which fails with a confusing "keystore password was
// incorrect" error.
fun keystoreValue(name: String): String? =
    keystoreProperties.getProperty(name)
        ?.trim()
        ?.takeIf { it.isNotEmpty() && !it.contains("CHANGE_ME") && !it.startsWith("YOUR_") }

val storeFilePath = keystoreValue("storeFile")
val storePasswordValue = keystoreValue("storePassword")
val keyPasswordValue = keystoreValue("keyPassword")
val keyAliasValue = keystoreValue("keyAlias")
val hasReleaseKeystore = storeFilePath != null &&
        storePasswordValue != null &&
        keyPasswordValue != null &&
        keyAliasValue != null &&
        project.file(storeFilePath).exists()

if (keystorePropertiesFile.exists() && !hasReleaseKeystore) {
    logger.warn(
        "android/key.properties is incomplete or points to a missing keystore. " +
        "Release builds will fall back to the debug key and Google Play will reject them. " +
        "Fill in storePassword, keyPassword and keyAlias before building the AAB."
    )
}

android {
    namespace = "com.gjandasher.digitalprinting"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gjandasher.digitalprinting"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storeFile = project.file(storeFilePath!!)
                storePassword = storePasswordValue
            }
        }
    }

    buildTypes {
        release {
            // Uses android/key.properties when present. Falls back to the debug
            // key so local release builds still work on a fresh checkout.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
