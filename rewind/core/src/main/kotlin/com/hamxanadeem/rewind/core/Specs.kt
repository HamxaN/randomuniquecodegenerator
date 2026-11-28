package com.hamxanadeem.rewind.core

/** The kinds of tower you can build. */
enum class TowerKind(
    val title: String,
    val blurb: String,
    val cost: Int,
    val range: Double,
    val cooldown: Double,
    val damage: Double,
    /** Projectile speed in cells per second; 0 = instant (lightning). */
    val shotSpeed: Double,
    val splash: Double = 0.0,
    val slow: Double = 0.0,
    val slowTime: Double = 0.0,
    val chains: Int = 0,
    val hitsFlying: Boolean = true,
) {
    BOLT("Bolt", "Fast single shots. Hits air.", 60, 2.6, 0.5, 14.0, 12.0),
    CANNON("Cannon", "Slow splash damage. Can't hit air.", 100, 2.3, 1.4, 34.0, 7.0, splash = 0.95, hitsFlying = false),
    FROST("Frost", "Slows enemies by half.", 80, 2.2, 0.9, 6.0, 9.0, splash = 0.7, slow = 0.5, slowTime = 1.8),
    TESLA("Tesla", "Lightning jumps between 3 enemies.", 140, 2.4, 1.1, 24.0, 0.0, chains = 3),
    SNIPER("Sniper", "Huge damage at long range. Picks the toughest.", 160, 5.5, 2.2, 95.0, 30.0),
    ;

    /** Gold to go from [level] to level + 1 (levels 1..3). */
    fun upgradeCost(level: Int): Int = when (level) {
        1 -> (cost * 0.8).toInt()
        2 -> (cost * 1.4).toInt()
        else -> 0
    }

    fun damageAt(level: Int): Double = damage * when (level) {
        2 -> 1.6
        3 -> 2.6
        else -> 1.0
    }

    fun rangeAt(level: Int): Double = range + 0.3 * (level - 1)

    fun cooldownAt(level: Int): Double = cooldown * when (level) {
        2 -> 0.88
        3 -> 0.77
        else -> 1.0
    }

    companion object {
        const val MAX_LEVEL = 3

        /** Which towers are open after beating [levelsBeaten] levels. */
        fun unlocked(levelsBeaten: Int): List<TowerKind> = buildList {
            add(BOLT)
            add(CANNON)
            if (levelsBeaten >= 1) add(FROST)
            if (levelsBeaten >= 2) add(TESLA)
            if (levelsBeaten >= 4) add(SNIPER)
        }
    }
}

/** The kinds of enemy. [threat] is used to build waves; [livesCost] is what a leak costs. */
enum class EnemyKind(
    val title: String,
    val hp: Double,
    val speed: Double,
    val reward: Int,
    val threat: Int,
    val armor: Double = 0.0,
    val flying: Boolean = false,
    val regen: Double = 0.0,
    val livesCost: Int = 1,
    val radius: Double = 0.28,
) {
    SCOUT("Scout", 40.0, 2.16, 4, 4, radius = 0.22),
    GRUNT("Grunt", 95.0, 1.35, 6, 8),
    SWARM("Swarm", 24.0, 2.3, 2, 2, radius = 0.16),
    FLYER("Flyer", 75.0, 1.76, 8, 9, flying = true, radius = 0.25),
    TANK("Tank", 340.0, 0.81, 16, 22, armor = 4.0, livesCost = 3, radius = 0.36),
    SPLITTER("Splitter", 150.0, 1.1, 9, 20, radius = 0.32),
    SHIELD("Warden", 170.0, 1.15, 12, 16, regen = 7.0, radius = 0.3),
    BOSS("Colossus", 1800.0, 0.57, 150, 160, armor = 6.0, livesCost = 10, radius = 0.5),
}
