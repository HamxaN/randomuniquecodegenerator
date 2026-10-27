package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.random.Random

class ArenaTest {

    private fun play(plan: AiPlan, m: Match) {
        m.face(plan.facing)
        m.select(plan.weapon)
        m.setAim(plan.aim)
        if (plan.weapon.mode == FireMode.TARGET) m.fireAt(plan.targetX, plan.targetY) else m.fire(plan.power)
    }

    @Test
    fun `every arena is the same for a seed, has land, and drops into the sea at the ends`() {
        for (arena in Arena.entries) for (seed in 1L..3L) {
            val a = Terrain.generate(seed, arena)
            val b = Terrain.generate(seed, arena)
            assertEquals(a.solidCount(), b.solidCount(), "$arena is deterministic")
            assertTrue(a.solidCount() > a.width * a.height / 30, "$arena has land")
            assertTrue(a.surfaces(3).isEmpty() && a.surfaces(a.width - 4).isEmpty(), "$arena seed $seed: worms can be knocked into the sea")
            val standable = (100 until a.width - 100 step 50).count { a.surfaces(it).isNotEmpty() }
            assertTrue(standable > 15, "$arena seed $seed has room to stand ($standable columns)")
        }
    }

    @Test
    fun `worms spawn safely in every arena`() {
        for (arena in Arena.entries) {
            val m = Match(MatchConfig(List(3) { TeamSetup("T$it", false) }, wormsPerTeam = 3, seed = 11, arena = arena))
            val events = ArrayList<GameEvent>()
            repeat(80) { events += m.update(0.05) }
            assertTrue(m.worms.all { it.alive && it.onGround && it.y < m.terrain.waterY }, "$arena: all worms landed")
            assertTrue(events.none { it is GameEvent.Damaged }, "$arena: nobody hurt by spawning")
        }
    }

    @Test
    fun `the moon has no wind and low gravity`() {
        val moon = Match(MatchConfig(listOf(TeamSetup("A", false), TeamSetup("B", false)), seed = 4, arena = Arena.MOON))
        assertEquals(0.0, moon.wind)
        repeat(40) { moon.update(0.05) }
        val w = moon.activeWorm
        val startY = w.y
        moon.backflip()
        var highest = startY
        repeat(60) {
            moon.update(0.02)
            highest = minOf(highest, w.y)
        }
        // A backflip on normal gravity rises about 66 px; on the moon it's about twice that.
        assertTrue(startY - highest > 90, "rose ${startY - highest}")
    }

    @Test
    fun `computer teams finish a match in every arena`() {
        for (arena in Arena.entries) {
            val m = Match(MatchConfig(listOf(TeamSetup("A", true), TeamSetup("B", true)), wormsPerTeam = 2, seed = 21, arena = arena))
            val random = Random(7)
            var t = 0.0
            var planned = -1
            while (m.phase != Phase.GAME_OVER && t < 3600) {
                if (m.phase == Phase.AIM && planned != m.turnNumber) {
                    repeat(20) { m.update(0.05) }
                    if (m.phase == Phase.AIM) play(Ai.plan(m, Difficulty.NORMAL, random), m)
                    planned = m.turnNumber
                }
                m.update(0.05)
                t += 0.05
            }
            assertTrue(m.phase == Phase.GAME_OVER, "$arena did not finish: turn ${m.turnNumber}")
        }
    }

    @Test
    fun `sudden death raises the water every turn`() {
        val m = Match(MatchConfig(listOf(TeamSetup("A", false), TeamSetup("B", false)), seed = 5))
        val start = m.terrain.waterY
        val rose = ArrayList<GameEvent.WaterRose>()
        while (m.turnNumber <= Match.SUDDEN_DEATH_ROUNDS * 2 + 2 && m.phase != Phase.GAME_OVER) {
            if (m.phase == Phase.AIM) m.skipTurn()
            rose += m.update(0.05).filterIsInstance<GameEvent.WaterRose>()
        }
        assertTrue(rose.first().first && rose.drop(1).none { it.first })
        assertEquals(start - rose.size * Match.WATER_RISE, m.terrain.waterY)
    }
}
