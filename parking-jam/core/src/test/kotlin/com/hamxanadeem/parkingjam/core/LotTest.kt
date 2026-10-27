package com.hamxanadeem.parkingjam.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class LotTest {

    @Test
    fun `a car drives out when its way is clear and bumps when it isn't`() {
        // A car facing right in front of a car facing down.
        val a = Car(0, 0, 1, 2, Dir.RIGHT, 0)
        val b = Car(1, 3, 0, 3, Dir.DOWN, 0)
        val lot = Lot(5, 5, listOf(a, b))
        val bump = lot.tap(0)
        assertTrue(bump is TapResult.Bumped)
        bump as TapResult.Bumped
        assertEquals(1, bump.blocker.id)
        assertEquals(1, bump.gap)
        assertEquals(1, lot.bumps)
        assertTrue(lot.tap(1) is TapResult.Exited)
        val out = lot.tap(0)
        assertTrue(out is TapResult.Exited)
        assertTrue(lot.cleared)
        assertEquals(2, lot.stars())
    }

    @Test
    fun `overlapping cars are rejected`() {
        val result = runCatching { Lot(4, 4, listOf(Car(0, 0, 0, 2, Dir.RIGHT, 0), Car(1, 1, 0, 2, Dir.DOWN, 0))) }
        assertTrue(result.isFailure)
    }

    @Test
    fun `levels are the same every time and get bigger`() {
        val a = LotGenerator.generate(12)
        val b = LotGenerator.generate(12)
        assertEquals(a.cars.toList(), b.cars.toList())
        assertTrue(LotGenerator.shape(80).width > LotGenerator.shape(1).width)
        assertTrue(LotGenerator.generate(40).cars.size > LotGenerator.generate(1).cars.size)
    }

    @Test
    fun `every level can be cleared, always with a hint available until it's done`() {
        for (level in 1..200) {
            val lot = LotGenerator.generate(level)
            assertTrue(lot.cars.size >= 4, "level $level has ${lot.cars.size} cars")
            var guard = 0
            while (!lot.cleared && guard++ < 200) {
                val car = lot.hint()
                assertNotNull(car, "level $level is stuck with ${lot.cars.size} cars left")
                assertTrue(lot.tap(car!!.id) is TapResult.Exited)
            }
            assertTrue(lot.cleared)
            assertEquals(3, lot.stars())
        }
    }

    @Test
    fun `levels are a real puzzle - some cars start blocked`() {
        for (level in 5..60 step 5) {
            val lot = LotGenerator.generate(level)
            val blocked = lot.cars.count { !lot.canExit(it) }
            assertTrue(blocked >= lot.cars.size / 3, "level $level: only $blocked of ${lot.cars.size} blocked")
        }
        assertFalse(LotGenerator.generate(1).cars.all { LotGenerator.generate(1).canExit(it) })
    }
}
