import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val storeFilePath: String? = keystoreProperties.getProperty("storeFile")?.trim()
val storePasswordValue: String? = keystoreProperties.getProperty("storePassword")?.trim()
val keyAliasValue: String? = keystoreProperties.getProperty("keyAlias")?.trim()
val keyPasswordValue: String? = keystoreProperties.getProperty("keyPassword")?.trim()
val resolvedStoreFile = storeFilePath
    ?.takeIf { it.isNotEmpty() }
    ?.let { path -> rootProject.file(path).takeIf { it.exists() } ?: file(path) }
val hasReleaseKeystore: Boolean = keystorePropertiesFile.exists() &&
    resolvedStoreFile != null &&
    resolvedStoreFile.exists() &&
    !storePasswordValue.isNullOrEmpty() &&
    !keyAliasValue.isNullOrEmpty() &&
    !keyPasswordValue.isNullOrEmpty()

android {
    namespace = "id.rindangalam.customer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.rindangalam.customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = resolvedStoreFile
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    val requireReleaseKeystore: Boolean =
        project.findProperty("REQUIRE_RELEASE_KEYSTORE")?.toString()?.toBoolean() == true

    buildTypes {
        release {
            if (requireReleaseKeystore && !hasReleaseKeystore) {
                throw GradleException(
                    "Release keystore (android/key.properties) wajib dikonfigurasi saat REQUIRE_RELEASE_KEYSTORE=true.",
                )
            }
            isMinifyEnabled = requireReleaseKeystore
            isShrinkResources = requireReleaseKeystore
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug keys for UAT testing when key.properties is not yet provisioned.
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
