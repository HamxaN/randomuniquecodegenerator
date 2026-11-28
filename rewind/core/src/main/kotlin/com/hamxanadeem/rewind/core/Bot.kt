package com.hamxanadeem.rewind.core

/**
 * A simple player used to check that levels can be won (and in the app's demo on the
 * title screen). It builds where a tower covers the most road, mixes tower types,
 * and upgrades once good spots run out.
 */
class Bot(private val useRewinds: Boolean = false) {
    private var lastLives = -1

    fun cover(level: Level, cell: Cell, kind: TowerKind): Double {
        val c = cell.center
        var n = 0
        var d = 0.0
        while (d < level.length) {
            if (level.at(d).dist(c) <= kind.range) n++
            d += 0.25
        }
        return n * 0.25
    }

    private fun bestCell(game: Game, kind: TowerKind): Pair<Cell, Double>? {
        var best: Pair<Cell, Double>? = null
        for (c in 0 until Level.COLS) for (r in 0 until Level.ROWS) {
            val cell = Cell(c, r)
            if (!game.level.buildable(cell) || game.state.towerAt(cell) != null) continue
            val v = cover(game.level, cell, kind)
            if (best == null || v > best.second) best = cell to v
        }
        return best
    }

    private fun want(game: Game): TowerKind {
        val have = game.state.towers.groupingBy { it.kind }.eachCount()
        val opts = game.unlocked
        val wave = game.level.waves.getOrNull(game.state.wave)
        if (wave != null && EnemyKind.FLYER in wave.kinds && (have[TowerKind.BOLT] ?: 0) < 3) return TowerKind.BOLT
        val order = listOf(TowerKind.BOLT, TowerKind.CANNON, TowerKind.BOLT, TowerKind.FROST, TowerKind.TESLA, TowerKind.SNIPER, TowerKind.CANNON)
        val n = game.state.towers.size
        return order.filter { it in opts }.let { it[n % it.size] }
    }

    /** One decision; call every tick or so. */
    fun act(game: Game) {
        if (game.state.over) return
        val s0 = game.state
        if (useRewinds && s0.waveActive && lastLives >= 0 && s0.lives < lastLives && game.canRewind) {
            game.rewind()
        }
        lastLives = game.state.lives
        repeat(3) {
            val kind = want(game)
            val spot = bestCell(game, kind)
            val good = spot != null && spot.second >= 2.0
            if (good && game.state.gold >= kind.cost) {
                game.build(spot!!.first, kind)
            } else if (!good || game.state.towers.size >= 14) {
                val t = game.state.towers.filter { it.level < TowerKind.MAX_LEVEL }
                    .minByOrNull { it.level * 1000 + it.kind.upgradeCost(it.level) }
                if (t != null && game.state.gold >= t.kind.upgradeCost(t.level)) game.upgrade(t.id)
            }
        }
        if (!game.state.waveActive) game.startWave()
    }

    /** Plays a whole level; returns the finished game. */
    fun play(game: Game, maxTicks: Int = 200_000): Game {
        var t = 0
        while (!game.state.over && t < maxTicks) {
            if (t % 10 == 0) act(game)
            game.tick()
            t++
        }
        return game
    }
}
