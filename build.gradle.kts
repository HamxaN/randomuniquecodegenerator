plugins {
    alias(libs.plugins.android.application) apply false
}

tasks.register("coreTest") {
    group = "verification"
    description = "Runs the unit tests of the pure-Kotlin game logic in :core."
    dependsOn(gradle.includedBuild("core").task(":test"))
}
