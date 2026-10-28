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

/** Tabs in the weapon picker. */
enum class WeaponCategory(val displayName: String) {
    MISSILES("Missiles"),
    BOMBS("Bombs"),
    STRIKES("Strikes"),
    GUNS("Guns"),
    TOOLS("Tools"),
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
    /** Lies still until armed, then goes off when a worm comes close. */
    val mine: Boolean = false,
    /** Walks along the ground and hops over bumps until its fuse runs out or it touches a worm. */
    val walker: Boolean = false,
    /** Steers itself towards the nearest enemy shortly after launch. */
    val homing: Boolean = false,
    /** Seconds it keeps boring through land after hitting it, before exploding. */
    val drill: Double = 0.0,
    /** Splits into its children at the top of its flight instead of on impact. */
    val splitAtApex: Boolean = false,
)

enum class Weapon(
    val displayName: String,
    val category: WeaponCategory,
    val mode: FireMode,
    /** Ammo per team at the start of a standard match; -1 means unlimited. */
    val startAmmo: Int,
    val spec: ProjectileSpec?,
    val launchSpeed: Double = 0.0,
    val description: String,
    /** Rough ratings from 0 to 5 for the picker's stat bars. */
    val power: Int,
    val blast: Int,
    val range: Int,
) {
    BAZOOKA(
        "Bazooka", WeaponCategory.MISSILES, FireMode.POWER, -1,
        ProjectileSpec(windFactor = 1.0, explosionRadius = 34.0, damage = 48), 520.0,
        "Rocket that explodes on impact. The wind pushes it.", 3, 3, 4,
    ),
    HOMING(
        "Homing Missile", WeaponCategory.MISSILES, FireMode.POWER, 2,
        ProjectileSpec(radius = 3.0, explosionRadius = 36.0, damage = 50, homing = true), 420.0,
        "Launch it anywhere: after a moment it locks on and chases the nearest enemy.", 3, 3, 5,
    ),
    DRILL(
        "Drill Missile", WeaponCategory.MISSILES, FireMode.POWER, 2,
        ProjectileSpec(radius = 3.0, windFactor = 0.5, explosionRadius = 40.0, damage = 52, drill = 0.55), 500.0,
        "Bores straight through the ground, then blows up. Finds worms hiding in caves.", 3, 3, 4,
    ),
    MIRV(
        "Cluster Missile", WeaponCategory.MISSILES, FireMode.POWER, 1,
        ProjectileSpec(
            radius = 3.5, windFactor = 0.8, explosionRadius = 20.0, damage = 15, splitAtApex = true, children = 4,
            childSpec = ProjectileSpec(radius = 3.0, explosionRadius = 32.0, damage = 34),
        ),
        480.0, "Splits into four missiles at the top of its flight. Rains destruction on an area.", 4, 4, 4,
    ),
    NAPALM(
        "Napalm Missile", WeaponCategory.MISSILES, FireMode.POWER, 1,
        ProjectileSpec(
            radius = 3.5, windFactor = 0.8, explosionRadius = 26.0, damage = 25, children = 8,
            childSpec = ProjectileSpec(radius = 2.5, windFactor = 0.4, bounce = 0.2, fuse = 1.8, explosionRadius = 14.0, damage = 9),
        ),
        480.0, "Explodes into burning blobs of fire that spread across the ground.", 4, 4, 4,
    ),
    NUKE(
        "Nuke", WeaponCategory.MISSILES, FireMode.POWER, 1,
        ProjectileSpec(radius = 5.0, windFactor = 0.6, explosionRadius = 115.0, damage = 80), 460.0,
        "The biggest blast in the game. One per match. Don't stand too close!", 5, 5, 4,
    ),
    GRENADE(
        "Grenade", WeaponCategory.BOMBS, FireMode.POWER, -1,
        ProjectileSpec(bounce = 0.45, fuse = 3.0, explosionRadius = 34.0, damage = 45), 440.0,
        "Bounces around and goes off after 3 seconds. Ignores wind.", 3, 3, 3,
    ),
    CLUSTER(
        "Cluster Bomb", WeaponCategory.BOMBS, FireMode.POWER, 2,
        ProjectileSpec(
            bounce = 0.4, fuse = 3.0, explosionRadius = 24.0, damage = 25, children = 5,
            childSpec = ProjectileSpec(radius = 2.0, explosionRadius = 18.0, damage = 18),
        ),
        440.0, "Bursts into five bomblets that rain down on the area.", 4, 4, 3,
    ),
    BANANA(
        "Banana Bomb", WeaponCategory.BOMBS, FireMode.POWER, 1,
        ProjectileSpec(
            radius = 4.0, bounce = 0.6, fuse = 3.0, explosionRadius = 44.0, damage = 55, children = 5,
            childSpec = ProjectileSpec(radius = 3.0, bounce = 0.5, fuse = 1.6, explosionRadius = 36.0, damage = 38),
        ),
        440.0, "Splits into five bouncing bananas. Total devastation.", 5, 5, 3,
    ),
    MEGA_GRENADE(
        "Mega Grenade", WeaponCategory.BOMBS, FireMode.POWER, 1,
        ProjectileSpec(radius = 4.0, bounce = 0.3, fuse = 3.0, explosionRadius = 76.0, damage = 85), 400.0,
        "A golden grenade with an enormous blast. Throw it far!", 5, 5, 2,
    ),
    DYNAMITE(
        "Dynamite", WeaponCategory.BOMBS, FireMode.DROP, 1,
        ProjectileSpec(bounce = 0.1, fuse = 4.0, explosionRadius = 58.0, damage = 72), 0.0,
        "Drop it, then run! Huge blast after 4 seconds.", 5, 4, 0,
    ),
    MINE(
        "Land Mine", WeaponCategory.BOMBS, FireMode.DROP, 2,
        ProjectileSpec(radius = 3.0, bounce = 0.15, explosionRadius = 30.0, damage = 40, mine = true), 0.0,
        "Tossed a short way. Arms after a few seconds, then blows up the next worm to wander close.", 3, 3, 1,
    ),
    SHOTGUN(
        "Shotgun", WeaponCategory.GUNS, FireMode.INSTANT, -1, null, 0.0,
        "Instant shot in a straight line. Knocks worms back.", 2, 1, 3,
    ),
    UZI(
        "Uzi", WeaponCategory.GUNS, FireMode.INSTANT, 2, null, 0.0,
        "Sprays ten bullets. Great for pushing worms off ledges.", 3, 1, 3,
    ),
    SNIPER(
        "Sniper Rifle", WeaponCategory.GUNS, FireMode.INSTANT, 1, null, 0.0,
        "One precise, long-range shot that hits hard.", 4, 0, 5,
    ),
    AIRSTRIKE(
        "Air Strike", WeaponCategory.STRIKES, FireMode.TARGET, 1,
        ProjectileSpec(windFactor = 0.6, explosionRadius = 26.0, damage = 28), 0.0,
        "Tap the map: five missiles drop from the sky.", 4, 4, 5,
    ),
    SHEEP(
        "Wild Sheep", WeaponCategory.STRIKES, FireMode.DROP, 1,
        ProjectileSpec(radius = 4.0, fuse = 6.0, explosionRadius = 52.0, damage = 65, walker = true), 0.0,
        "Waddles forward, hops over bumps and explodes on contact.", 4, 4, 3,
    ),
    BAT(
        "Baseball Bat", WeaponCategory.TOOLS, FireMode.INSTANT, 2, null, 0.0,
        "Whack the worm in front of you a long way. Home run!", 3, 0, 1,
    ),
    TELEPORT(
        "Teleport", WeaponCategory.TOOLS, FireMode.TARGET, 2, null, 0.0,
        "Tap anywhere open to beam your worm there. Ends your turn.", 0, 0, 5,
    ),
    GIRDER(
        "Girder", WeaponCategory.TOOLS, FireMode.TARGET, 2, null, 0.0,
        "Tap to build a steel beam: a bridge, a wall or a shelter. You can still attack afterwards.", 0, 0, 4,
    ),
    ;

    val unlimited: Boolean get() = startAmmo < 0

    companion object {
        const val SHOTGUN_DAMAGE = 25
        const val SHOTGUN_RANGE = 420.0
        const val UZI_BULLETS = 10
        const val UZI_DAMAGE = 5
        const val UZI_RANGE = 380.0
        const val SNIPER_DAMAGE = 45
        const val SNIPER_RANGE = 1100.0
        const val BAT_DAMAGE = 30
        const val BAT_RANGE = 26.0
        const val BAT_SPEED = 380.0
        const val AIRSTRIKE_MISSILES = 5
        const val AIRSTRIKE_SPACING = 26.0
        const val MINE_ARM_SECONDS = 3.5
        const val MINE_TRIGGER = 20.0
        const val SHEEP_SPEED = 70.0
        const val GIRDER_LENGTH = 70
        const val GIRDER_THICKNESS = 7
        const val HOMING_DELAY = 0.45
        const val HOMING_SPEED = 330.0
        const val HOMING_TURN = 4.5
    }
}

/**
 * Starting ammo for a whole match. Every set keeps at least one unlimited weapon,
 * so a team can always fire something.
 */
enum class WeaponSet(val displayName: String, val description: String) {
    STANDARD("Standard", "Every weapon, big ones limited"),
    ARTILLERY("Heavy Artillery", "Lots of missiles and big bombs"),
    SHARPSHOOTER("Sharpshooter", "Guns and tools only"),
    MAYHEM("Mayhem", "Everything, unlimited!"),
    ;

    fun ammo(weapon: Weapon): Int = when (this) {
        STANDARD -> weapon.startAmmo
        ARTILLERY -> when (weapon) {
            Weapon.BAZOOKA, Weapon.GRENADE, Weapon.CLUSTER, Weapon.HOMING, Weapon.DRILL -> -1
            Weapon.BANANA, Weapon.MEGA_GRENADE, Weapon.AIRSTRIKE, Weapon.SHEEP, Weapon.MIRV, Weapon.NAPALM -> 3
            Weapon.DYNAMITE, Weapon.MINE -> 4
            Weapon.NUKE -> 2
            Weapon.SHOTGUN, Weapon.UZI, Weapon.SNIPER -> 0
            else -> weapon.startAmmo
        }
        SHARPSHOOTER -> when (weapon) {
            Weapon.SHOTGUN, Weapon.UZI -> -1
            Weapon.SNIPER -> 5
            Weapon.BAT, Weapon.TELEPORT, Weapon.GIRDER -> 3
            else -> 0
        }
        MAYHEM -> -1
    }
}
