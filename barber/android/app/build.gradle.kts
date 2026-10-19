import java.util.Properties
import java.security.KeyStore
import java.security.cert.X509Certificate

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep upload credentials local. Debug builds do not require release credentials.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val uploadKeyAlias = keystoreProperties.getProperty("keyAlias")
val uploadStorePassword = keystoreProperties.getProperty("storePassword")
val uploadKeyPassword = keystoreProperties.getProperty("keyPassword")
val uploadStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }?.let { file(it) }
val uploadSigningConfigured = listOf(uploadKeyAlias, uploadStorePassword, uploadKeyPassword)
    .all { !it.isNullOrBlank() } && uploadStoreFile?.isFile == true
val debugSigningConfigured = uploadKeyAlias.equals("androiddebugkey", ignoreCase = true) ||
    uploadStoreFile?.name.equals("debug.keystore", ignoreCase = true)
// Explicit opt-in for a handoff artifact that still needs signing. Never upload it to Play.
val unsignedRelease = providers.gradleProperty("unsignedRelease")
    .orElse(providers.environmentVariable("BARBERCLUB_UNSIGNED_RELEASE"))
    .map { it.toBoolean() }.getOrElse(false)
val useUploadSigning = uploadSigningConfigured && !debugSigningConfigured && !unsignedRelease

android {
    namespace = "fr.barberclubgrenoble.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "fr.barberclubgrenoble.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (useUploadSigning) {
            create("release") {
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
                storeFile = uploadStoreFile
                storePassword = uploadStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (useUploadSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

val validateReleaseUploadSigning = tasks.register("validateReleaseUploadSigning") {
    group = "verification"
    description = "Reject missing or debug upload keys before packaging a Play release."
    doLast {
        if (unsignedRelease) {
            logger.warn("UNSIGNED release requested: the bundle must be signed before Play upload.")
        } else {
            check(uploadSigningConfigured && !debugSigningConfigured) {
                "Play release requires the real upload keystore in android/key.properties. " +
                    "Android debug keys are not accepted. For an explicitly unsigned handoff only, " +
                    "set BARBERCLUB_UNSIGNED_RELEASE=true."
            }
            val store = KeyStore.getInstance(uploadStoreFile!!, uploadStorePassword!!.toCharArray())
            check(store.isKeyEntry(uploadKeyAlias)) { "Upload alias is not a private-key entry." }
            val certificate = store.getCertificate(uploadKeyAlias) as? X509Certificate
                ?: error("Upload alias has no X.509 certificate.")
            check(!certificate.subjectX500Principal.name.contains("CN=Android Debug", ignoreCase = true)) {
                "An Android debug certificate cannot sign a Play release."
            }
            certificate.checkValidity()
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseUploadSigning)
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
