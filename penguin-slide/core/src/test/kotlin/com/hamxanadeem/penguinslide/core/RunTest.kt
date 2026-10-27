package com.hamxanadeem.penguinslide.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class RunTest {

    /** A decent player: dives on downhills, lets go on uphills, never spins. */
    private fun play(run: Run, seconds: Double, spin: Boolean = false): List<RunEvent> {
        val events = ArrayList<RunEvent>()
        var t = 0.0
        while (t < seconds && !run.isOver) {
            val p = run.penguin
            val holding = if (p.onGround) run.terrain.slopeAt(p.x) < 0 else spin
            events += run.update(1.0 / 60, holding)
            t += 1.0 / 60
        }
        return events
    }

    @Test
    fun `the clock runs out and ends the run`() {
        val run = Run(1)
        val events = play(run, 600.0)
        assertTrue(run.isOver)
        assertTrue(events.last() is RunEvent.TimeUp)
        assertTrue(run.distance > 0)
        assertEquals(0, run.update(1.0, false).size)
    }

    @Test
    fun `checkpoints add time`() {
        val run = Run(2)
        val events = play(run, 600.0)
        val checkpoints = events.filterIsInstance<RunEvent.Checkpoint>()
        assertTrue(checkpoints.isNotEmpty(), "never reached a checkpoint: ${run.distance}m")
        assertTrue(run.elapsed > Run.START_SECONDS)
        assertTrue(checkpoints.all { it.bonusSeconds >= Run.MIN_CHECKPOINT_BONUS })
    }

    @Test
    fun `fish can be caught and score adds up`() {
        val run = Run(3)
        play(run, 600.0)
        assertTrue(run.fishCaught > 0)
        assertEquals(
            run.distance + run.flips * Run.FLIP_POINTS + run.perfectLandings * Run.PERFECT_POINTS + run.fishCaught * Run.FISH_POINTS,
            run.score,
        )
    }

    @Test
    fun `spinning all the time in the air causes wipeouts`() {
        val events = play(Run(6), 120.0, spin = true)
        assertTrue(events.any { it == RunEvent.Wipeout } || events.any { it is RunEvent.Flips })
    }

    @Test
    fun `revive adds time once`() {
        val run = Run(4)
        play(run, 600.0)
        assertTrue(run.canRevive)
        run.revive()
        assertFalse(run.isOver)
        assertEquals(Run.REVIVE_SECONDS, run.timeLeft)
        play(run, 600.0)
        assertTrue(run.isOver)
        assertFalse(run.canRevive)
        assertThrows<IllegalStateException> { run.revive() }
    }

    @Test
    fun `fish listed for drawing are ahead and uncaught`() {
        val run = Run(5)
        val visible = run.fishBetween(0.0, 500.0)
        assertTrue(visible.isNotEmpty())
        assertTrue(visible.all { !it.caught && it.x in 0.0..500.0 })
    }

    @Test
    fun `progress banks runs and buys skins`() {
        val run = Run(7)
        play(run, 600.0)
        val progress = Progress().afterRun(run)
        assertEquals(run.fishCaught, progress.fish)
        assertEquals(run.score, progress.bestScore)
        assertEquals(run.fishCaught * 2, progress.addFish(run.fishCaught).fish)

        val rich = Progress(fish = 200)
        val cozy = SkinCatalog.byId("cozy")
        val bought = rich.buy(cozy)!!
        assertEquals(50, bought.fish)
        assertEquals(cozy, bought.skin)
        assertNull(bought.buy(cozy))
        assertNull(Progress(fish = 10).buy(cozy))
        assertEquals(SkinCatalog.default, Progress().select(cozy).skin)
        assertEquals(SkinCatalog.default, Progress(selectedSkin = "gone").skin)
    }
}
