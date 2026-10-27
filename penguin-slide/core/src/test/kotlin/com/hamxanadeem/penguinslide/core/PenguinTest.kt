package com.hamxanadeem.penguinslide.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.PI

class PenguinTest {

    private fun simulate(seed: Long, seconds: Double, holding: (Penguin) -> Boolean): Pair<Penguin, List<SlideEvent>> {
        val penguin = Penguin(Terrain(seed))
        val events = ArrayList<SlideEvent>()
        var t = 0.0
        while (t < seconds) {
            penguin.step(1.0 / 240, holding(penguin), events)
            t += 1.0 / 240
        }
        return penguin to events
    }

    @Test
    fun `slides downhill and speeds up`() {
        val penguin = Penguin(Terrain(1))
        val events = ArrayList<SlideEvent>()
        val start = penguin.speed
        repeat(240) { penguin.step(1.0 / 240, false, events) }
        assertTrue(penguin.x > 0)
        assertTrue(penguin.speed > start + 3, "speed ${penguin.speed}")
    }

    @Test
    fun `diving downhill is faster than not diving`() {
        val (lazy, _) = simulate(1, 1.0) { false }
        val (diver, _) = simulate(1, 1.0) { true }
        assertTrue(diver.speed > lazy.speed)
    }

    @Test
    fun `launches off crests and lands again`() {
        // Dive on downhills, let go on uphills: the classic technique.
        val (penguin, events) = simulate(2, 30.0) { p -> p.onGround && Terrain(2).slopeAt(p.x) < 0 }
        assertTrue(events.count { it == SlideEvent.TakeOff } >= 3, "events: $events")
        assertTrue(events.any { it == SlideEvent.PerfectLanding || it == SlideEvent.GoodLanding })
        assertTrue(penguin.x > 300, "only got to ${penguin.x}")
    }

    @Test
    fun `never sinks into the snow or produces NaN`() {
        val terrain = Terrain(4)
        val penguin = Penguin(terrain)
        val events = ArrayList<SlideEvent>()
        val random = kotlin.random.Random(4)
        var hold = false
        repeat(240 * 120) {
            if (it % 30 == 0) hold = random.nextBoolean()
            penguin.step(1.0 / 240, hold, events)
            assertTrue(penguin.x.isFinite() && penguin.y.isFinite())
            assertTrue(penguin.y >= terrain.heightAt(penguin.x) - 1e-6)
            assertTrue(penguin.speed <= Penguin.MAX_SPEED + 1e-6)
        }
    }

    @Test
    fun `angles wrap into range`() {
        assertEquals(0.0, Penguin.wrap(2 * PI), 1e-9)
        assertEquals(-PI / 2, Penguin.wrap(3 * PI / 2), 1e-9)
        assertEquals(PI / 2, Penguin.wrap(-3 * PI / 2), 1e-9)
    }
}
