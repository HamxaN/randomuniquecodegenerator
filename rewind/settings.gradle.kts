pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "RewindDefense"

// Pure-Kotlin game rules and simulation. A separate build so
// it can be tested without the Android SDK (`../gradlew -p core test`).
includeBuild("core")
include(":app")
