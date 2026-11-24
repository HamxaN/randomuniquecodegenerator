import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

/** Reads a value from `-Pname=...`, `~/.gradle/gradle.properties` or an environment variable. */
fun secret(name: String): String? =
    (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(name)?.takeIf { it.isNotBlank() }

val keystorePath = secret("KEYSTORE_PATH")

android {
    namespace = "com.hamxanadeem.clipcraft"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.hamxanadeem.clipcraft"
        minSdk = 26
        targetSdk = 36
        versionCode = secret("VERSION_CODE")?.toInt() ?: 1
        versionName = secret("VERSION_NAME") ?: "1.0.0"
        // Phones only: the bundled downloader (Python + FFmpeg) is large for each CPU type.
        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a")
        }
    }

    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = secret("KEYSTORE_PASSWORD")
                keyAlias = secret("KEY_ALIAS")
                keyPassword = secret("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    packaging {
        // The testing downloader runs Python and FFmpeg from the extracted native libraries.
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += setOf("META-INF/DEPENDENCIES", "META-INF/LICENSE*", "META-INF/NOTICE*", "META-INF/*.kotlin_module",
                "META-INF/versions/9/OSGI-INF/MANIFEST.MF")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = true
        // Dependency updates are handled by Dependabot rather than failing the build.
        disable += setOf("GradleDependency", "AndroidGradlePluginVersion", "NewerVersionAvailable")
        // Third-party libraries (JNA, OkHttp, Jackson) reference JVM APIs that are never called on Android.
        disable += setOf("InvalidPackage")
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("com.hamxanadeem.clipcraft:core")
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.recyclerview)
    implementation(libs.material)
    implementation(libs.media3.transformer)
    implementation(libs.media3.effect)
    implementation(libs.media3.common)
    implementation(libs.media3.exoplayer)
    implementation(libs.media3.ui)
    implementation(libs.play.services.auth)
    implementation(libs.mlkit.face)
    implementation(libs.ytdl.library)
    implementation(libs.ytdl.ffmpeg)
    implementation(libs.anthropic.java)
    implementation(libs.okhttp)
    implementation(libs.guava)
    implementation("com.alphacephei:vosk-android:${libs.versions.vosk.get()}@aar")
    implementation("net.java.dev.jna:jna:${libs.versions.jna.get()}@aar")
}
