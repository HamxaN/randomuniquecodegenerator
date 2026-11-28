package com.hamxanadeem.rewind.core

/** A small, fast, deterministic random number generator (xorshift64*). */
class Rng(seed: Long) {
    var state: Long = if (seed == 0L) 0x9E3779B97F4A7C15uL.toLong() else seed

    fun nextLong(): Long {
        var x = state
        x = x xor (x ushr 12)
        x = x xor (x shl 25)
        x = x xor (x ushr 27)
        state = x
        return x * 0x2545F4914F6CDD1DL
    }

    fun nextDouble(): Double = (nextLong() ushr 11).toDouble() / (1L shl 53).toDouble()

    fun nextInt(n: Int): Int = (nextDouble() * n).toInt().coerceIn(0, n - 1)
}

/** One enemy appearing [tick] ticks after the wave starts. */
data class Spawn(val tick: Int, val kind: EnemyKind)

/** A wave: who comes when, and how much tougher than base they are. */
data class Wave(val spawns: List<Spawn>, val hpScale: Double) {
    val kinds: Set<EnemyKind> get() = spawns.map { it.kind }.toSet()
    val hasBoss: Boolean get() = spawns.any { it.kind == EnemyKind.BOSS }
}

/** Builds each level's waves from its index, so they are the same for everyone. */
object Waves {
    const val TICKS = Sim.TICKS_PER_SECOND

    fun available(level: Int, wave: Int): List<EnemyKind> = buildList {
        add(EnemyKind.SCOUT)
        add(EnemyKind.GRUNT)
        if (wave >= 2) add(EnemyKind.SWARM)
        if (level >= 1 && wave >= 3) add(EnemyKind.FLYER)
        if (wave >= 5 || (level >= 2 && wave >= 3)) add(EnemyKind.TANK)
        if (level >= 2 && wave >= 5) add(EnemyKind.SPLITTER)
        if (level >= 3 && wave >= 4) add(EnemyKind.SHIELD)
    }

    fun budget(level: Int, wave: Int): Double = (40.0 + 16.0 * wave + 1.6 * wave * wave) * (1 + 0.15 * level)

    fun hpScale(level: Int, wave: Int): Double =
        (1 + (0.14 + 0.012 * level) * wave + 0.011 * wave * wave) * (1 + 0.05 * level)

    private fun interval(k: EnemyKind): Double = when (k) {
        EnemyKind.SWARM -> 0.22
        EnemyKind.SCOUT -> 0.4
        EnemyKind.GRUNT -> 0.6
        EnemyKind.TANK -> 1.3
        EnemyKind.BOSS -> 3.0
        else -> 0.75
    }

    /** Short roads give towers less time to shoot, so their enemies are a little softer. */
    fun roadFactor(length: Double): Double = (length / 45.0).coerceIn(0.85, 1.1)

    fun forLevel(level: Level): List<Wave> =
        (0 until level.waveCount).map { w -> make(level.index, w, level.waveCount, roadFactor(level.length)) }

    fun make(level: Int, wave: Int, count: Int, road: Double = 1.0): Wave {
        val rng = Rng(1_000_003L * (level + 1) + 7919L * (wave + 1))
        var budget = budget(level, wave)
        val groups = mutableListOf<Pair<EnemyKind, Int>>()
        val last = wave == count - 1
        if ((last && level >= 2) || (level >= 6 && wave == count / 2)) {
            groups += EnemyKind.BOSS to 1
            budget -= EnemyKind.BOSS.threat * 0.6
        }
        val pool = available(level, wave).toMutableList()
        // Lean on the newest enemy types, so each wave feels different.
        val picks = mutableListOf<EnemyKind>()
        val n = minOf(pool.size, if (wave < 2) 1 else 2 + rng.nextInt(2))
        repeat(n) {
            val i = if (rng.nextDouble() < 0.5) pool.size - 1 else rng.nextInt(pool.size)
            picks += pool.removeAt(i)
        }
        val share = budget.coerceAtLeast(8.0) / picks.size
        for (k in picks) groups += k to maxOf(1, (share / k.threat).toInt())
        val spawns = mutableListOf<Spawn>()
        var t = 0.0
        for ((k, c) in groups) {
            repeat(c) {
                spawns += Spawn((t * TICKS).toInt(), k)
                t += interval(k)
            }
            t += 1.0
        }
        return Wave(spawns, hpScale(level, wave) * road)
    }
}
