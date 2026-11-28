package com.hamxanadeem.rewind.core

/** Permanent upgrades bought with crystals. */
enum class Research(val title: String, val blurb: String, val max: Int, private val base: Int) {
    DAMAGE("Sharper Arsenal", "+6% damage for every tower", 5, 40),
    GOLD("War Chest", "+25 starting gold", 5, 30),
    REWIND("Time Crystal", "+1 rewind every wave", 1, 220),
    ;

    fun cost(currentLevel: Int): Int = base * (currentLevel + 1)
}

/** What the player has earned, saved on the phone. */
data class Progress(
    val stars: List<Int> = List(Level.ALL.size) { 0 },
    val crystals: Int = 0,
    val research: Map<Research, Int> = emptyMap(),
    val gamesPlayed: Int = 0,
) {
    fun level(r: Research) = research[r] ?: 0

    val levelsBeaten: Int get() = stars.count { it > 0 }

    val totalStars: Int get() = stars.sum()

    fun isUnlocked(levelIndex: Int) = levelIndex == 0 || (stars.getOrNull(levelIndex - 1) ?: 0) > 0

    fun towers(): List<TowerKind> = TowerKind.unlocked(levelsBeaten)

    fun newGame(level: Level) = Game(
        level,
        startGoldBonus = 25 * level(Research.GOLD),
        damageBonus = 1 + 0.06 * level(Research.DAMAGE),
        rewindsPerWave = 1 + level(Research.REWIND),
        unlocked = towers(),
    )

    /** Crystals for a finished level: 10 per star, +20 the first time it's beaten, 5 for trying. */
    fun reward(levelIndex: Int, starsEarned: Int): Int =
        if (starsEarned == 0) 5 else starsEarned * 10 + if ((stars.getOrNull(levelIndex) ?: 0) == 0) 20 else 0

    /** The progress after finishing a level ([bonusCrystals] e.g. from a doubled reward). */
    fun finish(levelIndex: Int, starsEarned: Int, crystalsEarned: Int): Progress = copy(
        stars = stars.mapIndexed { i, s -> if (i == levelIndex) maxOf(s, starsEarned) else s },
        crystals = crystals + crystalsEarned,
        gamesPlayed = gamesPlayed + 1,
    )

    fun canBuy(r: Research) = level(r) < r.max && crystals >= r.cost(level(r))

    fun buy(r: Research): Progress = if (!canBuy(r)) this else copy(
        crystals = crystals - r.cost(level(r)),
        research = research + (r to level(r) + 1),
    )

    fun encode(): String = buildString {
        append("v=1;stars=").append(stars.joinToString(","))
        append(";crystals=").append(crystals)
        append(";played=").append(gamesPlayed)
        for (r in Research.entries) append(";r.").append(r.name).append('=').append(level(r))
    }

    companion object {
        fun decode(text: String?): Progress {
            if (text.isNullOrBlank()) return Progress()
            return runCatching {
                val m = text.split(';').mapNotNull { kv -> kv.split('=', limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] } }.toMap()
                val saved = m["stars"].orEmpty().split(',').mapNotNull { it.toIntOrNull()?.coerceIn(0, 3) }
                Progress(
                    stars = List(Level.ALL.size) { saved.getOrElse(it) { 0 } },
                    crystals = m["crystals"]?.toIntOrNull()?.coerceAtLeast(0) ?: 0,
                    research = Research.entries.associateWith { (m["r.${it.name}"]?.toIntOrNull() ?: 0).coerceIn(0, it.max) }.filterValues { it > 0 },
                    gamesPlayed = m["played"]?.toIntOrNull() ?: 0,
                )
            }.getOrDefault(Progress())
        }
    }
}
