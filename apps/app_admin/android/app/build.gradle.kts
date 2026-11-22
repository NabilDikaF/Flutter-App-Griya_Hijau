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

val requireReleaseKeystore: Boolean =
    project.findProperty("REQUIRE_RELEASE_KEYSTORE")?.toString()?.equals("true", ignoreCase = true) == true
val allowDebugSigning: Boolean = !requireReleaseKeystore &&
    project.findProperty("ALLOW_DEBUG_SIGNING")?.toString()?.equals("true", ignoreCase = true) == true
val releaseKeystoreErrorMessage =
    "Release keystore tidak ditemukan atau tidak lengkap di android/key.properties. " +
        "Salin android/key.properties.example ke android/key.properties dan isi path keystore rilis yang valid. " +
        "Untuk uji coba lokal tanpa keystore rilis, aktifkan opt-out eksplisit -PALLOW_DEBUG_SIGNING=true " +
        "(atau env ORG_GRADLE_PROJECT_ALLOW_DEBUG_SIGNING=true saat memakai flutter build)."
val isReleaseTaskRequested: Boolean = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

android {
    namespace = "id.rindangalam.admin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.rindangalam.admin"
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

    buildTypes {
        release {
            if (!hasReleaseKeystore && !allowDebugSigning && isReleaseTaskRequested) {
                throw GradleException(releaseKeystoreErrorMessage)
            }
            isMinifyEnabled = hasReleaseKeystore
            isShrinkResources = hasReleaseKeystore
            if (hasReleaseKeystore) {
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro",
                )
            }
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                allowDebugSigning -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

if (!hasReleaseKeystore && !allowDebugSigning) {
    val missingKeystoreMsg = releaseKeystoreErrorMessage
    tasks.matching { task ->
        task.name == "assembleRelease" ||
            task.name == "bundleRelease" ||
            task.name == "packageRelease" ||
            task.name == "packageReleaseBundle"
    }.configureEach {
        doFirst {
            throw GradleException(missingKeystoreMsg)
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
