import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// android/key.properties and the keystore it references are local/CI secrets.
// Release tasks fail during configuration when either is absent or incomplete.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val requiredKeystoreProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let(rootProject::file)
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    requiredKeystoreProperties.all { !keystoreProperties.getProperty(it).isNullOrBlank() } &&
    releaseStoreFile?.isFile == true
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseTaskRequested) {
    check(hasReleaseKeystore) {
        "[PresenceKit] Release signing is required. Configure android/key.properties and its " +
            "keystore file; see android/key.properties.example. Debug signing is not valid for release."
    }
}

android {
    namespace = "com.presencekit.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.14904198"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.presencekit.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
