import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

/** Reads a value from `-Pname=...`, `~/.gradle/gradle.properties` or an environment variable. */
fun secret(name: String): String? =
    (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }
        ?: System.getenv(name)?.takeIf { it.isNotBlank() }

// Google's official AdMob test IDs. They always serve test ads and are safe to click.
// Release builds must use your own IDs (see docs/PLAY_STORE_RELEASE.md).
val testAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val testBannerId = "ca-app-pub-3940256099942544/6300978111"
val testInterstitialId = "ca-app-pub-3940256099942544/1033173712"
val testRewardedId = "ca-app-pub-3940256099942544/5224354917"

val keystorePath = secret("KEYSTORE_PATH")

android {
    namespace = "com.hamxanadeem.parkingjam"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.hamxanadeem.parkingjam"
        minSdk = 26
        targetSdk = 36
        versionCode = secret("VERSION_CODE")?.toInt() ?: 1
        versionName = secret("VERSION_NAME") ?: "1.0.0"
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
            manifestPlaceholders["admobAppId"] = testAdmobAppId
            buildConfigField("String", "ADMOB_BANNER_ID", "\"$testBannerId\"")
            buildConfigField("String", "ADMOB_INTERSTITIAL_ID", "\"$testInterstitialId\"")
            buildConfigField("String", "ADMOB_REWARDED_ID", "\"$testRewardedId\"")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            manifestPlaceholders["admobAppId"] = secret("ADMOB_APP_ID") ?: testAdmobAppId
            buildConfigField("String", "ADMOB_BANNER_ID", "\"${secret("ADMOB_BANNER_ID") ?: testBannerId}\"")
            buildConfigField("String", "ADMOB_INTERSTITIAL_ID", "\"${secret("ADMOB_INTERSTITIAL_ID") ?: testInterstitialId}\"")
            buildConfigField("String", "ADMOB_REWARDED_ID", "\"${secret("ADMOB_REWARDED_ID") ?: testRewardedId}\"")
        }
    }

    buildFeatures {
        buildConfig = true
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
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("com.hamxanadeem.parkingjam:core")
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.play.services.ads)
    implementation(libs.ump)
}
