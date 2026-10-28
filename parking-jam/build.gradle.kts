plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
}

tasks.register("coreTest") {
    group = "verification"
    description = "Runs the unit tests of the pure-Kotlin game rules in :core."
    dependsOn(gradle.includedBuild("core").task(":test"))
}
