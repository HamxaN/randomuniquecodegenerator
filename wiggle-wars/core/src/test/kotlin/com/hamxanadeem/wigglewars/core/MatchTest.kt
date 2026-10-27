package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.PI

class MatchTest {

    /** A new match, with its opening "turn started" event already read. */
    private fun match(seed: Long = 3, worms: Int = 3, teams: Int = 2, cpu: Boolean = false) =
        Match(MatchConfig(List(teams) { TeamSetup("Team $it", cpu) }, wormsPerTeam = worms, seed = seed)).also {
            assertTrue(it.update(0.0).single() is GameEvent.TurnStarted)
        }

    /** Runs until the match is waiting for the active worm again (or over). */
    private fun runUntilNextTurn(m: Match, maxSeconds: Double = 60.0): List<GameEvent> {
        val events = ArrayList<GameEvent>()
        var t = 0.0
        while (t < maxSeconds) {
            val e = m.update(0.05)
            events += e
            t += 0.05
            if (e.any { it is GameEvent.TurnStarted || it is GameEvent.GameOver }) break
        }
        return events
    }

    @Test
    fun `terrain is the same for a seed, has land, and the edges are sea`() {
        val a = Terrain.generate(9)
        val b = Terrain.generate(9)
        assertEquals(a.solidCount(), b.solidCount())
        assertTrue(a.solidCount() > a.width * a.height / 5)
        assertEquals(null, a.groundBelow(2))
        assertEquals(null, a.groundBelow(a.width - 3))
        assertNotNull(a.groundBelow(a.width / 2))
    }

    @Test
    fun `explosions carve round holes`() {
        val t = Terrain(100, 100)
        for (y in 50 until 100) for (x in 0 until 100) t.set(x, y, true)
        val before = t.solidCount()
        val area = t.carve(50.0, 50.0, 10.0)!!
        assertTrue(t.solidCount() < before)
        assertFalse(t.isSolid(50, 55))
        assertTrue(t.isSolid(50, 70))
        assertTrue(area.left <= 40 && area.right >= 60)
        assertEquals(null, t.carve(50.0, 10.0, 5.0), "nothing to carve in the sky")
    }

    @Test
    fun `worms spawn on land, apart, and settle without getting hurt`() {
        val m = match(worms = 4, teams = 3)
        assertEquals(12, m.worms.size)
        val events = ArrayList<GameEvent>()
        repeat(60) { events += m.update(0.05) }
        assertTrue(m.worms.all { it.alive && it.onGround }, "all landed")
        assertTrue(events.none { it is GameEvent.Damaged })
        assertTrue(m.worms.all { it.y < m.terrain.waterY })
    }

    @Test
    fun `active worm can walk and jump`() {
        val m = match()
        repeat(40) { m.update(0.05) }
        val w = m.activeWorm
        val startX = w.x
        m.walk(1)
        repeat(40) { m.update(0.05) }
        m.walk(0)
        val walked = w.x - startX
        m.walk(-1)
        repeat(40) { m.update(0.05) }
        m.walk(0)
        assertTrue(kotlin.math.abs(walked) > 5 || kotlin.math.abs(w.x - startX) > 5, "worm should move")
        repeat(40) { m.update(0.05) }
        m.jump()
        val events = m.update(0.02)
        assertTrue(events.any { it is GameEvent.Jumped })
        assertFalse(w.onGround)
        repeat(80) { m.update(0.05) }
        assertTrue(!w.alive || w.onGround)
    }

    @Test
    fun `a bazooka shot at your feet hurts, digs a crater and ends the turn`() {
        val m = match()
        repeat(40) { m.update(0.05) }
        val w = m.activeWorm
        val solid = m.terrain.solidCount()
        m.setAim(PI / 2)
        assertTrue(m.fire(0.2))
        val events = ArrayList<GameEvent>()
        repeat(20) { events += m.update(0.05) }
        assertTrue(events.any { it is GameEvent.Explosion })
        assertTrue(events.any { it is GameEvent.Damaged && it.worm == w.id })
        assertTrue(m.terrain.solidCount() < solid)
        assertEquals(Phase.SETTLE, m.phase)
    }

    @Test
    fun `turns rotate between teams and the wind changes`() {
        val m = match()
        val teamsSeen = HashSet<Int>()
        val winds = HashSet<Double>()
        winds += m.wind
        repeat(6) {
            repeat(10) { m.update(0.05) }
            teamsSeen += m.currentTeam
            m.skipTurn()
            runUntilNextTurn(m)
            winds += m.wind
        }
        assertEquals(setOf(0, 1), teamsSeen)
        assertTrue(winds.size > 3)
        // Each team's worms take turns in order.
        val seen = HashSet<Int>()
        repeat(6) {
            seen += m.activeWormId
            m.skipTurn()
            runUntilNextTurn(m)
        }
        assertTrue(seen.size >= 4)
    }

    @Test
    fun `the turn timer runs out`() {
        val m = match()
        val team = m.currentTeam
        var timeUp = false
        var t = 0.0
        while (!timeUp && t < Match.TURN_SECONDS + 2) {
            timeUp = m.update(0.05).any { it == GameEvent.TimeUp }
            t += 0.05
        }
        assertTrue(timeUp)
        assertTrue(t >= Match.TURN_SECONDS - 0.1)
        runUntilNextTurn(m)
        assertNotEquals(team, m.currentTeam)
    }

    @Test
    fun `worms that fall in the water drown`() {
        val m = match()
        val victim = m.worms.first { it.id != m.activeWormId }
        victim.onGround = false
        victim.y = m.terrain.waterY + 5.0
        val events = m.update(0.05)
        assertTrue(events.any { it is GameEvent.Drowned && it.worm == victim.id })
        assertFalse(victim.alive)
    }

    @Test
    fun `grenades wait for their fuse and clusters split`() {
        val m = match()
        repeat(40) { m.update(0.05) }
        val team = m.currentTeam
        m.select(Weapon.CLUSTER)
        m.setAim(-PI / 3)
        assertTrue(m.fire(0.5))
        val events = ArrayList<GameEvent>()
        repeat(10) { events += m.update(0.1) }
        assertTrue(events.none { it is GameEvent.Explosion }, "fuse is 3 s")
        repeat(80) { events += m.update(0.1) }
        assertTrue(events.count { it is GameEvent.Explosion } >= 2, "cluster plus bomblets")
        assertEquals(Weapon.CLUSTER.startAmmo - 1, m.ammo(Weapon.CLUSTER, team))
    }

    @Test
    fun `limited weapons run out`() {
        val m = match()
        val team = m.currentTeam
        assertEquals(1, m.ammo(Weapon.AIRSTRIKE))
        assertTrue(m.select(Weapon.AIRSTRIKE))
        // Aim at an enemy so the missiles land on solid ground.
        val target = m.worms.first { it.team != team }
        assertTrue(m.fireAt(target.x, 100.0))
        assertEquals(0, m.ammo(Weapon.AIRSTRIKE, team))
        val events = runUntilNextTurn(m)
        val missiles = events.count { it is GameEvent.Explosion } - events.count { it is GameEvent.Died } +
            events.count { it is GameEvent.Splash } - events.count { it is GameEvent.Drowned }
        assertEquals(Weapon.AIRSTRIKE_MISSILES, missiles)
        assertTrue(m.select(Weapon.BANANA), "every weapon is available from the start")
    }

    @Test
    fun `teleport moves the worm and ends the turn`() {
        val m = match()
        repeat(40) { m.update(0.05) }
        val w = m.activeWorm
        m.select(Weapon.TELEPORT)
        assertFalse(m.fireAt(w.x, m.terrain.height - 1.0), "can't teleport into rock or sea")
        val tx = m.terrain.width / 2.0
        assertTrue(m.fireAt(tx, 60.0))
        assertEquals(tx, w.x)
        assertEquals(Phase.SETTLE, m.phase)
    }

    @Test
    fun `last team standing wins`() {
        val m = match()
        val loser = 1 - m.currentTeam
        m.teams[loser].worms.forEach { it.health = 0 }
        m.skipTurn()
        val events = runUntilNextTurn(m, maxSeconds = 120.0)
        val gone = events.count { it is GameEvent.Died && m.worms[it.worm].team == loser } +
            events.count { it is GameEvent.Drowned && m.worms[it.worm].team == loser }
        assertEquals(m.config.wormsPerTeam, gone)
        val over = events.filterIsInstance<GameEvent.GameOver>().single()
        assertEquals(1 - loser, over.winner)
        assertEquals(Phase.GAME_OVER, m.phase)
    }

    @Test
    fun `bonus bananas go to human teams only`() {
        val m = Match(MatchConfig(listOf(TeamSetup("You", false), TeamSetup("CPU", true)), bonusBananas = 2))
        assertEquals(Weapon.BANANA.startAmmo + 2, m.ammo(Weapon.BANANA, 0))
        assertEquals(Weapon.BANANA.startAmmo, m.ammo(Weapon.BANANA, 1))
    }
}
