package com.hamxanadeem.rewind.core

/** Where an enemy was in the future you rewound from. */
data class GhostDot(val id: Int, val kind: EnemyKind, val x: Double, val y: Double, val hp: Double)

/**
 * The future you came back from: every enemy's position for each tick from the
 * moment you returned to until the moment you rewound, plus what it cost you.
 */
class Ghosts(
    val fromTick: Int,
    val untilTick: Int,
    private val frames: Map<Int, List<GhostDot>>,
    val livesLost: Int,
    /** Where enemies broke through (the end of the road), if they did. */
    val leaked: Boolean,
) {
    fun at(tick: Int): List<GhostDot> = frames[tick] ?: emptyList()

    fun active(tick: Int) = tick in fromTick..untilTick
}

/**
 * A level being played. Keeps the last [REWIND_SECONDS] of an active wave so you can
 * go back once per wave, see the "ghosts" of what is about to happen, and change
 * your towers.
 */
class Game(
    val level: Level,
    startGoldBonus: Int = 0,
    damageBonus: Double = 1.0,
    rewindsPerWave: Int = 1,
    val unlocked: List<TowerKind> = TowerKind.entries,
) {
    companion object {
        const val REWIND_SECONDS = 10
        const val MAX_HISTORY = REWIND_SECONDS * Sim.TICKS_PER_SECOND
    }

    var state: State = Sim.start(level, startGoldBonus, damageBonus, rewindsPerWave)
        private set
    private val history = ArrayDeque<State>()
    var ghosts: Ghosts? = null
        private set
    var rewindsUsed = 0
        private set

    /** Seconds of history that a rewind would take you back. */
    val rewindSeconds: Double get() = history.size.toDouble() / Sim.TICKS_PER_SECOND

    val canRewind: Boolean get() = !state.over && state.waveActive && state.rewindsLeft > 0 && history.size >= Sim.TICKS_PER_SECOND

    fun tick(): List<Event> {
        if (state.over) return emptyList()
        val events = mutableListOf<Event>()
        if (state.waveActive) {
            history.addLast(state.copy())
            while (history.size > MAX_HISTORY) history.removeFirst()
        }
        Sim.step(state, level, events)
        if (!state.waveActive) history.clear()
        ghosts?.let { if (state.tick > it.untilTick || !state.waveActive) ghosts = null }
        return events
    }

    /**
     * Goes back up to [REWIND_SECONDS]. Returns the states passed through, newest first,
     * so the screen can play the rewind; null if you can't rewind now.
     */
    fun rewind(): List<State>? {
        if (!canRewind) return null
        val now = state
        val past = history.toList()
        val frames = HashMap<Int, List<GhostDot>>(past.size + 1)
        for (st in past + now) {
            frames[st.tick] = st.enemies.map { e ->
                val p = level.at(e.dist)
                GhostDot(e.id, e.kind, p.x, p.y, e.hp / e.maxHp)
            }
        }
        val target = past.first().copy()
        target.rewindsLeft = now.rewindsLeft - 1
        ghosts = Ghosts(target.tick, now.tick, frames, now.livesLost - target.livesLost, now.livesLost > target.livesLost)
        history.clear()
        state = target
        rewindsUsed++
        return (past + now).reversed()
    }

    /** One more rewind this wave (e.g. from a rewarded ad). */
    fun grantRewind() {
        state.rewindsLeft++
    }

    /** Extra lives to keep going after losing (e.g. from a rewarded ad). */
    fun revive(lives: Int) {
        if (!state.lost) return
        state.lost = false
        state.lives = lives
        // Clear the enemies that broke through so the player gets a fair restart of the wave.
        state.enemies.clear()
        state.shots.clear()
        history.clear()
        ghosts = null
    }

    fun build(cell: Cell, kind: TowerKind): Tower? = if (kind in unlocked) Sim.build(state, level, cell, kind) else null
    fun upgrade(towerId: Int) = Sim.upgrade(state, towerId)
    fun sell(towerId: Int) = Sim.sell(state, towerId)
    fun startWave() = Sim.startWave(state, level)

    /** 3 stars for losing at most 10% of lives, 2 for half, 1 for surviving. */
    fun stars(): Int {
        if (!state.won) return 0
        val left = state.lives.toDouble() / level.lives
        return when {
            left >= 0.9 -> 3
            left >= 0.5 -> 2
            else -> 1
        }
    }
}
