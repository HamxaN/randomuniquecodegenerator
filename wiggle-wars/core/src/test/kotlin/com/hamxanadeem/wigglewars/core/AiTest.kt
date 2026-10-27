package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.random.Random

class AiTest {

    private fun play(plan: AiPlan, m: Match) {
        m.face(plan.facing)
        m.select(plan.weapon)
        m.setAim(plan.aim)
        if (plan.weapon.mode == FireMode.TARGET) m.fireAt(plan.targetX, plan.targetY) else m.fire(plan.power)
    }

    @Test
    fun `predictions match what really happens`() {
        val m = Match(MatchConfig(listOf(TeamSetup("A", false), TeamSetup("B", false)), seed = 5))
        repeat(40) { m.update(0.05) }
        val w = m.activeWorm
        val predicted = m.predict(Weapon.GRENADE, w.facing, -0.6, 0.7)
        m.select(Weapon.GRENADE)
        m.setAim(-0.6)
        m.fire(0.7)
        var explosion: GameEvent.Explosion? = null
        repeat(100) { if (explosion == null) explosion = m.update(0.05).filterIsInstance<GameEvent.Explosion>().firstOrNull() }
        if (predicted != null) {
            val e = explosion!!
            assertTrue(kotlin.math.hypot(e.x - predicted.first, e.y - predicted.second) < 1.0, "predicted $predicted, got ${e.x},${e.y}")
        }
    }

    @Test
    fun `hard AI usually hits`() {
        var hits = 0
        val trials = 12
        for (seed in 1L..trials) {
            val m = Match(MatchConfig(listOf(TeamSetup("A", true), TeamSetup("B", true)), seed = seed, difficulty = Difficulty.HARD))
            repeat(40) { m.update(0.05) }
            val team = m.currentTeam
            val plan = Ai.plan(m, Difficulty.HARD, Random(seed))
            play(plan, m)
            var t = 0.0
            var hit = false
            while (t < 30) {
                val events = m.update(0.05)
                if (events.any { e -> e is GameEvent.Damaged && m.worms[e.worm].team != team }) hit = true
                if (events.any { it is GameEvent.TurnStarted || it is GameEvent.GameOver }) break
                t += 0.05
            }
            if (hit) hits++
        }
        assertTrue(hits >= trials / 2, "hard AI hit $hits of $trials")
    }

    @Test
    fun `computer teams play whole matches to the end`() {
        for (seed in 1L..3L) {
            val m = Match(MatchConfig(listOf(TeamSetup("A", true), TeamSetup("B", true), TeamSetup("C", true)), wormsPerTeam = 2, seed = seed, difficulty = Difficulty.NORMAL))
            val random = Random(seed)
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
                for (w in m.worms) assertTrue(w.x.isFinite() && w.y.isFinite())
            }
            assertTrue(m.phase == Phase.GAME_OVER, "seed $seed did not finish: turn ${m.turnNumber}")
        }
    }
}
