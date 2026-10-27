package com.hamxanadeem.penguinslide.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.abs

class TerrainTest {

    @Test
    fun `same seed makes the same hills`() {
        val a = Terrain(5)
        val b = Terrain(5)
        for (x in 0..3000 step 7) assertEquals(a.heightAt(x.toDouble()), b.heightAt(x.toDouble()))
    }

    @Test
    fun `hills are smooth with no jumps`() {
        val t = Terrain(11)
        var x = 0.0
        var previous = t.heightAt(x)
        while (x < 5000) {
            x += 0.05
            val h = t.heightAt(x)
            assertTrue(h.isFinite())
            assertTrue(abs(h - previous) < 0.2, "jump at $x")
            previous = h
        }
    }

    @Test
    fun `slope matches the change in height`() {
        val t = Terrain(3)
        for (x in listOf(5.0, 33.3, 120.0, 777.7, 2500.5)) {
            val numeric = (t.heightAt(x + 1e-4) - t.heightAt(x - 1e-4)) / 2e-4
            assertEquals(numeric, t.slopeAt(x), 1e-3)
        }
    }

    @Test
    fun `curvature matches the change in slope`() {
        val t = Terrain(3)
        for (x in listOf(5.0, 33.3, 120.0, 777.7, 2500.5)) {
            val numeric = (t.slopeAt(x + 1e-4) - t.slopeAt(x - 1e-4)) / 2e-4
            assertEquals(numeric, t.curvatureAt(x), 1e-3)
        }
    }

    @Test
    fun `run starts downhill from a high peak`() {
        val t = Terrain(1)
        assertEquals(Terrain.START_HEIGHT, t.heightAt(0.0), 1e-9)
        assertTrue(t.heightAt(8.0) < t.heightAt(0.0))
    }

    @Test
    fun `hills get bigger further away`() {
        val t = Terrain(9)
        fun range(from: Double, to: Double): Double {
            val hs = (0..400).map { t.heightAt(from + (to - from) * it / 400) }
            return hs.max() - hs.min()
        }
        assertTrue(range(4000.0, 4600.0) > range(100.0, 700.0))
    }
}
