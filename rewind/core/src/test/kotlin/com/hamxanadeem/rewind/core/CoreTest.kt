package com.hamxanadeem.rewind.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class LevelTest {
    @Test
    fun `every map is valid and has room to build`() {
        assertEquals(8, Level.ALL.size)
        for (lv in Level.ALL) {
            assertTrue(lv.length > 20, lv.name)
            assertTrue(lv.road.size > 15, lv.name)
            val free = (0 until Level.COLS).sumOf { c -> (0 until Level.ROWS).count { r -> lv.buildable(Cell(c, r)) } }
            assertTrue(free >= 60, "${lv.name} has $free free cells")
            // The road starts and ends off the map.
            fun cellOf(p: Pt) = Cell(kotlin.math.floor(p.x).toInt(), kotlin.math.floor(p.y).toInt())
            assertFalse(Level.onMap(cellOf(lv.points.first())), lv.name)
            assertFalse(Level.onMap(cellOf(lv.points.last())), lv.name)
        }
    }

    @Test
    fun `walking along the road`() {
        val lv = Level.ALL[0]
        assertEquals(lv.points.first(), lv.at(-1.0))
        assertEquals(lv.points.last(), lv.at(lv.length + 5))
        val p = lv.at(3.0)
        assertEquals(2.5, p.y, 1e-9)
        assertEquals(2.5, p.x, 1e-9)
    }

    @Test
    fun `waves get tougher and are the same every time`() {
        for (lv in Level.ALL) {
            val w = lv.waves
            assertEquals(lv.waveCount, w.size)
            for (i in 1 until w.size) assertTrue(w[i].hpScale > w[i - 1].hpScale)
            for (i in 1 until w.size) assertTrue(Waves.budget(lv.index, i) > Waves.budget(lv.index, i - 1))
            assertEquals(w, Waves.forLevel(lv))
            if (lv.index >= 2) assertTrue(w.last().hasBoss, "${lv.name} ends with a boss")
            assertTrue(w.all { it.spawns.isNotEmpty() })
        }
        assertFalse(Level.ALL[0].waves.any { it.hasBoss })
        assertTrue(EnemyKind.FLYER !in Level.ALL[0].waves.flatMap { it.kinds })
    }
}

class SimTest {
    private val lv = Level.ALL[0]

    private fun cellNear(d: Double): Cell {
        val p = lv.at(d)
        // A free cell next to the road at that point.
        return listOf(Cell(p.x.toInt(), p.y.toInt() - 1), Cell(p.x.toInt(), p.y.toInt() + 1), Cell(p.x.toInt() + 1, p.y.toInt()))
            .first { lv.buildable(it) }
    }

    @Test
    fun `building, upgrading and selling`() {
        val s = Sim.start(lv)
        val cell = cellNear(3.0)
        assertFalse(Sim.canBuild(s, lv, lv.road.first(), TowerKind.BOLT))
        val t = Sim.build(s, lv, cell, TowerKind.BOLT)!!
        assertEquals(lv.startGold - 60, s.gold)
        assertNull(Sim.build(s, lv, cell, TowerKind.BOLT), "one tower per cell")
        assertTrue(Sim.upgrade(s, t.id))
        assertEquals(2, t.level)
        assertEquals(60 + 48, t.spent)
        assertTrue(Sim.upgrade(s, t.id))
        assertFalse(Sim.upgrade(s, t.id), "max level is 3")
        val before = s.gold
        assertTrue(Sim.sell(s, t.id))
        assertEquals(before + (t.spent * 0.7).toInt(), s.gold)
        assertTrue(s.towers.isEmpty())
        s.gold = 10
        assertFalse(Sim.canBuild(s, lv, cell, TowerKind.CANNON), "can't afford")
    }

    @Test
    fun `towers kill, rewards are paid, leaks cost lives, waves end with a bonus`() {
        val s = Sim.start(lv)
        Sim.build(s, lv, cellNear(2.0), TowerKind.BOLT)
        Sim.build(s, lv, cellNear(6.0), TowerKind.BOLT)
        Sim.build(s, lv, cellNear(10.0), TowerKind.CANNON)
        assertTrue(Sim.startWave(s, lv))
        assertFalse(Sim.startWave(s, lv), "already running")
        val events = mutableListOf<Event>()
        var guard = 0
        while (s.waveActive && guard++ < 10_000) Sim.step(s, lv, events)
        assertEquals(1, s.wave)
        assertTrue(events.any { it is Event.Killed })
        assertTrue(events.any { it is Event.WaveCleared })
        assertTrue(s.kills > 0)

        // With no towers, everything leaks.
        val empty = Sim.start(lv)
        Sim.startWave(empty, lv)
        guard = 0
        while (empty.waveActive && guard++ < 10_000) Sim.step(empty, lv)
        assertEquals(lv.lives - lv.waves[0].spawns.sumOf { it.kind.livesCost }, empty.lives)
    }

    @Test
    fun `cannons can't hit flyers, frost slows, tesla chains`() {
        val s = Sim.start(lv)
        val cell = cellNear(4.0)
        Sim.build(s, lv, cell, TowerKind.CANNON)
        s.enemies += Enemy(99, EnemyKind.FLYER, 4.0, 1000.0, 1000.0)
        repeat(60) { Sim.step(s, lv) }
        assertEquals(1000.0, s.enemies.first().hp, 1e-9)

        val f = Sim.start(lv)
        Sim.build(f, lv, cellNear(4.0), TowerKind.FROST)
        f.enemies += Enemy(1, EnemyKind.GRUNT, 3.0, 1000.0, 1000.0)
        repeat(30) { Sim.step(f, lv) }
        assertEquals(0.5, f.enemies.first().slowFactor, 1e-9)

        val z = Sim.start(lv)
        z.gold = 1000
        Sim.build(z, lv, cellNear(4.0), TowerKind.TESLA)
        for (i in 0 until 4) z.enemies += Enemy(10 + i, EnemyKind.GRUNT, 3.5 + i * 0.4, 1000.0, 1000.0)
        val ev = mutableListOf<Event>()
        Sim.step(z, lv, ev)
        val zap = ev.filterIsInstance<Event.Zap>().single()
        assertEquals(1 + 4, zap.points.size, "tower plus 4 enemies")
        assertEquals(4, z.enemies.count { it.hp < 1000.0 })
    }

    @Test
    fun `armour and research`() {
        val s = Sim.start(lv, damageBonus = 1.5)
        Sim.build(s, lv, cellNear(4.0), TowerKind.BOLT)
        s.enemies += Enemy(1, EnemyKind.TANK, 4.0, 1000.0, 1000.0)
        var guard = 0
        while (s.enemies.first().hp == 1000.0 && guard++ < 200) Sim.step(s, lv)
        assertEquals(1000.0 - (14 * 1.5 - 4.0), s.enemies.first().hp, 1e-9)
    }

    @Test
    fun `splitters burst into swarms`() {
        val s = Sim.start(lv)
        s.enemies += Enemy(1, EnemyKind.SPLITTER, 5.0, 0.0, 100.0)
        Sim.step(s, lv)
        assertEquals(3, s.enemies.count { it.kind == EnemyKind.SWARM })
    }
}

class RewindTest {
    private fun midWave(): Game {
        val g = Game(Level.ALL[1])
        val bot = Bot()
        repeat(40) { bot.act(g) }
        g.startWave()
        repeat(Game.MAX_HISTORY + 90) { g.tick() }
        return g
    }

    @Test
    fun `the same choices replay the same future`() {
        val g = midWave()
        val now = g.state.signature()
        val tickNow = g.state.tick
        assertTrue(g.canRewind)
        val played = g.rewind()!!
        assertEquals(Game.MAX_HISTORY + 1, played.size)
        assertEquals(tickNow - Game.MAX_HISTORY, g.state.tick)
        while (g.state.tick < tickNow) g.tick()
        // Only the rewind count differs.
        assertEquals(now, g.state.signature())
    }

    @Test
    fun `rewinding restores gold and towers and shows the ghosts`() {
        val g = midWave()
        val back = Game.MAX_HISTORY
        val towersBefore = g.state.towers.size
        val enemiesNow = g.state.enemies.map { it.id }.toSet()
        g.rewind()
        val ghosts = g.ghosts!!
        assertTrue(ghosts.active(g.state.tick))
        // At the moment we rewound from, the ghosts are exactly the enemies we left.
        assertEquals(enemiesNow, ghosts.at(ghosts.untilTick).map { it.id }.toSet())
        assertEquals(towersBefore, g.state.towers.size)
        assertEquals(0, g.state.rewindsLeft)
        assertFalse(g.canRewind, "one rewind per wave")
        g.grantRewind()
        repeat(40) { g.tick() }
        assertTrue(g.canRewind, "an ad can grant another")
        repeat(back) { g.tick() }
        assertNull(g.ghosts, "ghosts fade once you pass the moment you came from")
    }

    @Test
    fun `changing the past changes the future`() {
        val g = midWave()
        val future = g.state.signature()
        val tickNow = g.state.tick
        g.rewind()
        g.state.gold += 500
        val free = (0 until Level.COLS).flatMap { c -> (0 until Level.ROWS).map { r -> Cell(c, r) } }
            .first { g.level.buildable(it) && g.state.towerAt(it) == null }
        assertNotNull(g.build(free, TowerKind.BOLT))
        while (g.state.tick < tickNow) g.tick()
        assertNotEquals(future, g.state.signature())
    }

    @Test
    fun `no rewinding outside a wave or too early`() {
        val g = Game(Level.ALL[0])
        assertFalse(g.canRewind)
        assertNull(g.rewind())
        g.startWave()
        repeat(10) { g.tick() }
        assertFalse(g.canRewind, "needs at least a second of history")
    }

    @Test
    fun `revive after losing`() {
        val g = Game(Level.ALL[0])
        var guard = 0
        while (!g.state.over && guard++ < 100_000) {
            if (!g.state.waveActive) g.startWave()
            g.tick()
        }
        assertTrue(g.state.lost, "no towers loses")
        g.revive(10)
        assertFalse(g.state.lost)
        assertEquals(10, g.state.lives)
    }
}

class BalanceTest {
    private fun progressBefore(i: Int) = Progress(stars = List(Level.ALL.size) { if (it < i) 2 else 0 })

    @Test
    fun `a sensible player can beat every level with what they've unlocked`() {
        for (lv in Level.ALL.dropLast(1)) {
            val g = Bot().play(progressBefore(lv.index).newGame(lv))
            assertTrue(g.state.won, "${lv.name}: wave ${g.state.wave}, lives ${g.state.lives}")
        }
        val last = Level.ALL.last()
        val researched = progressBefore(last.index).copy(research = mapOf(Research.DAMAGE to 1, Research.GOLD to 1))
        assertTrue(Bot().play(researched.newGame(last)).state.won, "the final level needs a little research")
    }

    @Test
    fun `stars follow lives left`() {
        val g = Bot().play(Game(Level.ALL[0]))
        assertTrue(g.state.won)
        assertEquals(3, g.stars())
        assertEquals(0, Game(Level.ALL[0]).stars())
    }
}

class ProgressTest {
    @Test
    fun `unlocks, rewards, research and saving`() {
        var p = Progress()
        assertTrue(p.isUnlocked(0))
        assertFalse(p.isUnlocked(1))
        assertEquals(listOf(TowerKind.BOLT, TowerKind.CANNON), p.towers())
        assertEquals(50, p.reward(0, 3), "first clear bonus")
        p = p.finish(0, 3, p.reward(0, 3))
        assertEquals(30, p.reward(0, 3), "no bonus the second time")
        assertTrue(p.isUnlocked(1))
        assertTrue(TowerKind.FROST in p.towers())
        assertEquals(5, p.reward(1, 0))
        assertTrue(p.canBuy(Research.DAMAGE))
        p = p.buy(Research.DAMAGE)
        assertEquals(1, p.level(Research.DAMAGE))
        assertEquals(10, p.crystals)
        assertFalse(p.canBuy(Research.REWIND))
        assertEquals(p, p.buy(Research.REWIND))
        assertEquals(p, Progress.decode(p.encode()))
        assertEquals(Progress(), Progress.decode(null))
        assertEquals(Progress(), Progress.decode("garbage"))
        val g = p.newGame(Level.ALL[0])
        assertEquals(1.06, g.state.damageBonus, 1e-9)
        assertEquals(null, g.build(Cell(0, 0), TowerKind.SNIPER), "locked towers can't be built")
    }
}
