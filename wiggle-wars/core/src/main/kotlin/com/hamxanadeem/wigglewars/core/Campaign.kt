package com.hamxanadeem.wigglewars.core

/**
 * One battle in the campaign. You always play the first team; [enemyWorms] lists
 * the computer teams. Stars: 1 for winning, 1 for losing no worms, 1 for winning
 * within [parTurns] turns.
 */
data class Mission(
    val number: Int,
    val title: String,
    val brief: String,
    val arena: Arena,
    val myWorms: Int,
    val enemyWorms: List<Int>,
    val difficulty: Difficulty,
    val weaponSet: WeaponSet = WeaponSet.STANDARD,
    val enemyHealth: Int = Worm.START_HEALTH,
    val parTurns: Int,
) {
    fun config(seed: Long, bonusAmmo: Map<Weapon, Int> = emptyMap()): MatchConfig {
        val teams = listOf(TeamSetup("You", false)) + enemyWorms.indices.map { TeamSetup(ENEMY_NAMES[it], true) }
        return MatchConfig(
            teams = teams,
            wormsPerTeam = myWorms,
            seed = seed,
            difficulty = difficulty,
            arena = arena,
            weaponSet = weaponSet,
            bonusAmmo = bonusAmmo,
            wormsByTeam = listOf(myWorms) + enemyWorms,
            cpuHealth = enemyHealth,
        )
    }

    private companion object {
        val ENEMY_NAMES = listOf("Red Raiders", "Green Goons", "Gold Grubs")
    }
}

/** A permanent upgrade bought with coins: one more of [weapon] at the start of every offline battle. */
data class Upgrade(val weapon: Weapon, val price: Int, val max: Int = 3)

object Campaign {

    val missions: List<Mission> = listOf(
        Mission(1, "Boot Camp", "One sleepy worm. Drag to aim, hold FIRE, let go.", Arena.HILLS, 3, listOf(1), Difficulty.EASY, enemyHealth = 60, parTurns = 6),
        Mission(2, "First Blood", "Two enemies on the hills. Watch the wind!", Arena.HILLS, 3, listOf(2), Difficulty.EASY, enemyHealth = 80, parTurns = 10),
        Mission(3, "Desert Storm", "Fight across the canyon.", Arena.DUNES, 3, listOf(2), Difficulty.EASY, parTurns = 12),
        Mission(4, "Island Hopper", "Knock them into the sea.", Arena.ISLANDS, 3, listOf(3), Difficulty.EASY, parTurns = 14),
        Mission(5, "Castle Siege", "Blast your way into their castle.", Arena.FORTRESS, 3, listOf(3), Difficulty.NORMAL, parTurns = 14),
        Mission(6, "Into the Dark", "No air strikes under the rock. Try the Drill Missile.", Arena.CAVERN, 3, listOf(3), Difficulty.NORMAL, parTurns = 16),
        Mission(7, "Sky High", "One bad step and it's a long way down.", Arena.SKY, 3, listOf(3), Difficulty.NORMAL, parTurns = 14),
        Mission(8, "Cold Front", "Strong winds in the mountains.", Arena.SNOW, 3, listOf(3), Difficulty.NORMAL, parTurns = 16),
        Mission(9, "Hot Zone", "Four of them on the volcano. Homing missiles help.", Arena.VOLCANO, 3, listOf(4), Difficulty.NORMAL, parTurns = 18),
        Mission(10, "One Small Step", "Half gravity: shots fly twice as far.", Arena.MOON, 3, listOf(4), Difficulty.NORMAL, parTurns = 16),
        Mission(11, "Sugar Rush", "Heavy artillery in Candy Land.", Arena.CANDY, 3, listOf(4), Difficulty.NORMAL, WeaponSet.ARTILLERY, parTurns = 16),
        Mission(12, "Two Fronts", "Two enemy teams at once.", Arena.HILLS, 3, listOf(2, 2), Difficulty.NORMAL, parTurns = 20),
        Mission(13, "Sharpshooters", "Guns only. Line up your shots.", Arena.DUNES, 3, listOf(3), Difficulty.NORMAL, WeaponSet.SHARPSHOOTER, parTurns = 16),
        Mission(14, "Mayhem Island", "Everything unlimited. Go wild!", Arena.ISLANDS, 3, listOf(4), Difficulty.NORMAL, WeaponSet.MAYHEM, parTurns = 16),
        Mission(15, "Fortress Breach", "Five defenders, and they aim well.", Arena.FORTRESS, 3, listOf(5), Difficulty.HARD, parTurns = 22),
        Mission(16, "Deep Caverns", "A tougher fight underground.", Arena.CAVERN, 3, listOf(4), Difficulty.HARD, parTurns = 20),
        Mission(17, "Storm Peaks", "Two teams in a blizzard.", Arena.SNOW, 4, listOf(3, 3), Difficulty.HARD, parTurns = 24),
        Mission(18, "Meteor Shower", "Low gravity and heavy artillery.", Arena.MOON, 3, listOf(4), Difficulty.HARD, WeaponSet.ARTILLERY, parTurns = 18),
        Mission(19, "Floating Fortress", "Two teams on the sky islands.", Arena.SKY, 3, listOf(3, 3), Difficulty.HARD, parTurns = 22),
        Mission(20, "Eruption", "Five tough worms on the volcano.", Arena.VOLCANO, 4, listOf(5), Difficulty.HARD, enemyHealth = 120, parTurns = 22),
        Mission(21, "Candy Crush", "Three teams want your candy.", Arena.CANDY, 4, listOf(2, 2, 2), Difficulty.HARD, parTurns = 26),
        Mission(22, "Last Stand", "Two of you against five. Use every trick.", Arena.HILLS, 2, listOf(5), Difficulty.HARD, parTurns = 20),
        Mission(23, "Lunar War", "Three teams on the moon.", Arena.MOON, 4, listOf(3, 3, 3), Difficulty.HARD, parTurns = 28),
        Mission(24, "Final Boss", "Their toughest team. Bring your nukes.", Arena.VOLCANO, 5, listOf(5), Difficulty.HARD, WeaponSet.ARTILLERY, enemyHealth = 150, parTurns = 30),
    )

    val upgrades: List<Upgrade> = listOf(
        Upgrade(Weapon.HOMING, 120),
        Upgrade(Weapon.DRILL, 120),
        Upgrade(Weapon.MIRV, 180),
        Upgrade(Weapon.NAPALM, 180),
        Upgrade(Weapon.BANANA, 220),
        Upgrade(Weapon.NUKE, 400),
    )

    fun mission(number: Int): Mission = missions[number - 1]

    /** Stars earned for a finished mission (0 if lost). */
    fun stars(mission: Mission, won: Boolean, wormsLost: Int, turns: Int): Int {
        if (!won) return 0
        var stars = 1
        if (wormsLost == 0) stars++
        if (turns <= mission.parTurns) stars++
        return stars
    }

    /** Coins for a result: some for trying, more per star, and a bonus for each newly earned star. */
    fun coins(stars: Int, previousBest: Int): Int = 10 + stars * 20 + (stars - previousBest).coerceAtLeast(0) * 30
}
