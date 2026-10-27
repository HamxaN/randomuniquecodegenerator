package com.hamxanadeem.wigglewars.core

/** How a weapon is used. */
enum class FireMode {
    /** Aim, hold to charge power, release. */
    POWER,
    /** Aim and fire instantly. */
    INSTANT,
    /** Tap a point on the map. */
    TARGET,
    /** Dropped at the worm's feet. */
    DROP,
}

/** What a projectile does. Distances in pixels, times in seconds. */
data class ProjectileSpec(
    val radius: Double = 3.0,
    val windFactor: Double = 0.0,
    /** 0 = explode on impact; otherwise bounce with this restitution until the fuse ends. */
    val bounce: Double = 0.0,
    val fuse: Double? = null,
    val explosionRadius: Double,
    val damage: Int,
    val children: Int = 0,
    val childSpec: ProjectileSpec? = null,
)

enum class Weapon(
    val displayName: String,
    val mode: FireMode,
    /** Ammo per team at the start of a match; -1 means unlimited. */
    val startAmmo: Int,
    val spec: ProjectileSpec?,
    val launchSpeed: Double = 0.0,
) {
    BAZOOKA("Bazooka", FireMode.POWER, -1, ProjectileSpec(windFactor = 1.0, explosionRadius = 34.0, damage = 48), 520.0),
    GRENADE("Grenade", FireMode.POWER, -1, ProjectileSpec(bounce = 0.45, fuse = 3.0, explosionRadius = 34.0, damage = 45), 440.0),
    CLUSTER(
        "Cluster Bomb", FireMode.POWER, 3,
        ProjectileSpec(
            bounce = 0.4, fuse = 3.0, explosionRadius = 24.0, damage = 25, children = 5,
            childSpec = ProjectileSpec(radius = 2.0, explosionRadius = 18.0, damage = 18),
        ),
        440.0,
    ),
    SHOTGUN("Shotgun", FireMode.INSTANT, -1, null),
    BAT("Baseball Bat", FireMode.INSTANT, 2, null),
    DYNAMITE("Dynamite", FireMode.DROP, 2, ProjectileSpec(bounce = 0.1, fuse = 4.0, explosionRadius = 58.0, damage = 72)),
    AIRSTRIKE("Air Strike", FireMode.TARGET, 1, ProjectileSpec(windFactor = 0.6, explosionRadius = 26.0, damage = 28)),
    TELEPORT("Teleport", FireMode.TARGET, 2, null),
    BANANA(
        "Banana Bomb", FireMode.POWER, 0,
        ProjectileSpec(
            radius = 4.0, bounce = 0.6, fuse = 3.0, explosionRadius = 44.0, damage = 55, children = 5,
            childSpec = ProjectileSpec(radius = 3.0, bounce = 0.5, fuse = 1.6, explosionRadius = 36.0, damage = 38),
        ),
        440.0,
    ),
    ;

    companion object {
        const val SHOTGUN_DAMAGE = 25
        const val SHOTGUN_RANGE = 420.0
        const val BAT_DAMAGE = 30
        const val BAT_RANGE = 26.0
        const val BAT_SPEED = 380.0
        const val AIRSTRIKE_MISSILES = 5
        const val AIRSTRIKE_SPACING = 26.0
    }
}
