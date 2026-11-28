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

// Google's official test ads. Real IDs come from secrets for release builds only.
val testAppId = "ca-app-pub-3940256099942544~3347511713"
val testBanner = "ca-app-pub-3940256099942544/9214589741"
val testInterstitial = "ca-app-pub-3940256099942544/1033173712"
val testRewarded = "ca-app-pub-3940256099942544/5224354917"

android {
    namespace = "com.hamxanadeem.rewind"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.hamxanadeem.rewind"
        minSdk = 26
        targetSdk = 36
        versionCode = secret("VERSION_CODE")?.toInt() ?: 1
        versionName = secret("VERSION_NAME") ?: "1.0.0"
    }

    buildFeatures {
        buildConfig = true
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
            // Debug builds always use test ads, so you can't get your AdMob account flagged.
            manifestPlaceholders["admobAppId"] = testAppId
            buildConfigField("String", "AD_BANNER", "\"$testBanner\"")
            buildConfigField("String", "AD_INTERSTITIAL", "\"$testInterstitial\"")
            buildConfigField("String", "AD_REWARDED", "\"$testRewarded\"")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            manifestPlaceholders["admobAppId"] = secret("ADMOB_APP_ID") ?: testAppId
            buildConfigField("String", "AD_BANNER", "\"${secret("ADMOB_BANNER_ID") ?: testBanner}\"")
            buildConfigField("String", "AD_INTERSTITIAL", "\"${secret("ADMOB_INTERSTITIAL_ID") ?: testInterstitial}\"")
            buildConfigField("String", "AD_REWARDED", "\"${secret("ADMOB_REWARDED_ID") ?: testRewarded}\"")
            if (keystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = true
        // Dependency updates are handled separately rather than failing the build.
        disable += setOf("GradleDependency", "AndroidGradlePluginVersion", "NewerVersionAvailable")
        // A landscape-only game: locking orientation is intentional.
        disable += setOf("LockedOrientationActivity", "DiscouragedApi")
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("com.hamxanadeem.rewind:core")
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.play.services.ads)
    implementation(libs.ump)
    implementation(libs.billing)
}
