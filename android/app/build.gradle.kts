import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localSigningFile = rootProject.file("key.properties")
val localSigningProperties = Properties()
if (localSigningFile.isFile) {
    localSigningFile.inputStream().use { localSigningProperties.load(it) }
}
val localKeystorePath = localSigningProperties.getProperty("storeFile")?.trim().orEmpty()
val localSigningFields = listOf("storePassword", "keyPassword", "keyAlias")
val hasLocalSigningCredentials =
    localSigningFields.all { !localSigningProperties.getProperty(it).isNullOrBlank() } &&
        localKeystorePath.isNotBlank()
val localKeystoreFile = if (localKeystorePath.isNotBlank()) {
    rootProject.file(localKeystorePath)
} else {
    null
}
if (hasLocalSigningCredentials && localKeystoreFile?.isFile != true) {
    throw GradleException("The release signing keystore configured in android/key.properties was not found.")
}

android {
    namespace = "app.noor.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.nova.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasLocalSigningCredentials) {
        signingConfigs.create("upload") {
            keyAlias = localSigningProperties.getProperty("keyAlias")
            keyPassword = localSigningProperties.getProperty("keyPassword")
            storeFile = requireNotNull(localKeystoreFile)
            storePassword = localSigningProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("profile") {
            signingConfig = if (hasLocalSigningCredentials) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        release {
            // Use the existing debug fallback until a complete local upload-key config exists.
            signingConfig = if (hasLocalSigningCredentials) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
            // Task 127: R8 minification (Flutter 3.47+ enables it for release by
            // default) obfuscates the jlibtorrent/SWIG wrappers — torrents then die
            // with unreadable errors like `TorrentException(torrent_error): g0.d`
            // (NoClassDefFoundError on the renamed libtorrent_jni class). Keep the
            // engine unobfuscated until a maintained keep-rules file exists.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // On-device torrent streaming engine (libtorrent rasterbar via jlibtorrent).
    // Prebuilt natives ship inside the AARs below, so no NDK is required.
    // Keep Java wrappers and native ARM artifacts on the same maintained
    // libtorrent release. 1.2.0.18 dates from 2018 and misses years of Android,
    // DHT, tracker and NAT traversal fixes.
    val jlibtorrentVersion = "2.0.12.9"
    implementation("com.frostwire:jlibtorrent:$jlibtorrentVersion")
    implementation("com.frostwire:jlibtorrent-android-arm64:$jlibtorrentVersion")
    implementation("com.frostwire:jlibtorrent-android-arm:$jlibtorrentVersion")
}
