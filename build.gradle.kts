plugins {
    alias(libs.plugins.android.application) apply false
    // Puts Kotlin Gradle plugin (libs.versions.toml) on the classpath so AGP's built-in Kotlin
    // compiles with the same Kotlin version as :core (AGP alone defaults to an older one).
    alias(libs.plugins.kotlin.jvm) apply false
}

tasks.register("coreTest") {
    group = "verification"
    description = "Runs the unit tests of the pure-Kotlin game logic in :core."
    dependsOn(gradle.includedBuild("core").task(":test"))
}
