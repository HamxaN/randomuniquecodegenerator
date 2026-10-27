package com.hamxanadeem.neonrunner.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RunTest {

    private fun runFor(run: Run, seconds: Double): List<RunEvent> {
        val out = ArrayList<RunEvent>()
        var t = 0.0
        while (t < seconds) {
            out += run.update(1 / 60.0)
            t += 1 / 60.0
        }
        return out
    }

    /** An empty track with just [obstacle] a few metres ahead. */
    private fun track(kind: ObstacleKind, ahead: Double = 5.0): Run {
        val run = Run(seed = 1)
        run.obstacles.clear()
        run.orbs.clear()
        run.powerUps.clear()
        run.obstacles += Obstacle(run.z + ahead, run.lane, kind)
        return run
    }

    @Test
    fun `the same seed builds the same track`() {
        val a = Run(seed = 42)
        val b = Run(seed = 42)
        runFor(a, 3.0)
        runFor(b, 3.0)
        assertEquals(a.obstacles.map { it.z to it.lane }, b.obstacles.map { it.z to it.lane })
    }

    @Test
    fun `every row leaves at least one lane free`() {
        val run = Run(seed = 7)
        repeat(4000) {
            for ((_, row) in run.obstacles.groupBy { it.z }) assertTrue(row.size < Run.LANES, "row blocks every lane")
            run.update(1 / 30.0)
            if (!run.alive) run.revive()
        }
    }

    @Test
    fun `barriers need a jump, beams a slide, walls a lane change`() {
        val crash = track(ObstacleKind.BARRIER)
        assertTrue(runFor(crash, 1.0).any { it is RunEvent.Crashed })

        val jump = track(ObstacleKind.BARRIER)
        jump.jump()
        runFor(jump, 1.0)
        assertTrue(jump.alive)

        val slide = track(ObstacleKind.BEAM)
        slide.slide()
        runFor(slide, 1.0)
        assertTrue(slide.alive)

        val wall = track(ObstacleKind.WALL)
        wall.jump()
        runFor(wall, 1.0)
        assertFalse(wall.alive, "you can't jump a wall")

        val dodge = track(ObstacleKind.WALL)
        dodge.left()
        runFor(dodge, 1.0)
        assertTrue(dodge.alive)
    }

    @Test
    fun `a shield takes one hit and a revive clears the way`() {
        val run = track(ObstacleKind.WALL)
        run.powerUps += PowerUp(run.z + 1, run.lane, PowerKind.SHIELD)
        val events = runFor(run, 1.0)
        assertTrue(events.any { it is RunEvent.ShieldBroke })
        assertTrue(run.alive)

        val dead = track(ObstacleKind.WALL)
        runFor(dead, 1.0)
        assertFalse(dead.alive)
        dead.revive()
        assertTrue(dead.alive)
        runFor(dead, 2.0)
        assertTrue(dead.alive)
        dead.obstacles += Obstacle(dead.z + 3, dead.lane, ObstacleKind.WALL)
        runFor(dead, 1.0)
        dead.revive()
        assertFalse(dead.alive, "only one revive per run")
    }

    @Test
    fun `orbs are collected in your lane, and by the magnet from any lane`() {
        val run = Run(seed = 3)
        run.obstacles.clear()
        run.orbs.clear()
        run.powerUps.clear()
        run.orbs += Orb(run.z + 3, run.lane, high = false)
        run.orbs += Orb(run.z + 4, (run.lane + 1) % Run.LANES, high = false)
        runFor(run, 1.0)
        assertEquals(1, run.orbsTaken)

        run.powerUps += PowerUp(run.z + 2, run.lane, PowerKind.MAGNET)
        run.orbs += Orb(run.z + 6, (run.lane + 1) % Run.LANES, high = false)
        run.orbs += Orb(run.z + 7, (run.lane + 2) % Run.LANES, high = true)
        runFor(run, 1.0)
        assertEquals(3, run.orbsTaken)
        assertTrue(run.score > run.z.toInt())
    }

    @Test
    fun `an autopilot that dodges sensibly survives five minutes`() {
        for (seed in 1L..3L) {
            val run = Run(seed)
            var t = 0.0
            while (t < 300 && run.alive) {
                autopilot(run)
                run.update(1 / 60.0)
                t += 1 / 60.0
            }
            assertTrue(run.alive, "seed $seed crashed at ${run.z.toInt()} m (speed ${run.speed})")
            assertTrue(run.speed > Run.START_SPEED)
        }
    }

    /** Looks at the next row and does what a player would. */
    private fun autopilot(run: Run) {
        val lookahead = run.speed * 0.45
        val row = run.obstacles.filter { it.z > run.z + 0.3 && it.z < run.z + lookahead }.groupBy { it.z }.minByOrNull { it.key } ?: return
        val inLane = row.value.firstOrNull { it.lane == run.lane }
        val blocked = { l: Int -> row.value.any { it.lane == l && it.kind == ObstacleKind.WALL } }
        if (inLane?.kind == ObstacleKind.WALL || (inLane != null && row.key - run.z < run.speed * 0.12)) {
            // Head for the nearest lane with nothing in it.
            val free = (0 until Run.LANES).filter { l -> row.value.none { it.lane == l } }
            val target = free.minByOrNull { kotlin.math.abs(it - run.lane) } ?: (0 until Run.LANES).first { !blocked(it) }
            if (target < run.lane) run.left() else if (target > run.lane) run.right()
            return
        }
        val dist = row.key - run.z
        when (inLane?.kind) {
            ObstacleKind.BARRIER -> if (dist < run.speed * 0.3 && !run.jumping) run.jump()
            ObstacleKind.BEAM -> if (dist < run.speed * 0.3 && !run.sliding) run.slide()
            else -> Unit
        }
    }
}
