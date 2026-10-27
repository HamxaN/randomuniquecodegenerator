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

rootProject.name = "IdleBakery"

// Pure-Kotlin game rules. A separate build so they can be tested without the
// Android SDK (`../gradlew -p core test`).
includeBuild("core")
include(":app")
