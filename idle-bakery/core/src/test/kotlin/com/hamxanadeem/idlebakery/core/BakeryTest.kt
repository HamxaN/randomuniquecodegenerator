package com.hamxanadeem.idlebakery.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

class BakeryTest {

    private val now = 1_000_000_000L

    /** A bakery with some money, via the save format. */
    private fun bakery(money: Double, levels: String = "1,0,0,0,0,0,0,0", managers: String = "0,0,0,0,0,0,0,0", stars: Int = 0, earned: Double = money): Bakery =
        Bakery.decode("v1;$money;$earned;$stars;0;0;$levels;$managers;0,0,0,0,0,0,0,0;0,0,0,0,0,0,0,0")!!

    @Test
    fun `starts with one cookie oven that bakes when tapped`() {
        val b = Bakery()
        assertTrue(b.isUnlocked(0))
        assertFalse(b.isRunning(0))
        assertTrue(b.tap(0))
        assertFalse(b.tap(0), "already baking")
        assertEquals(0, b.tick(0.3, now).size)
        val payouts = b.tick(0.4, now)
        assertEquals(listOf(Payout(0, 1.0)), payouts)
        assertEquals(1.0, b.money)
        assertFalse(b.isRunning(0), "a hand-baked batch stops")
    }

    @Test
    fun `locked stations can't bake`() {
        assertFalse(Bakery().tap(3))
    }

    @Test
    fun `upgrades cost more each time and match the sum of single buys`() {
        val b = bakery(1e12)
        val bulk = b.upgradeCost(1, 10)
        var single = 0.0
        val copy = bakery(1e12)
        repeat(10) {
            single += copy.upgradeCost(1, 1)
            assertTrue(copy.buy(1, 1))
        }
        assertEquals(single, bulk, single * 1e-9)
        assertTrue(copy.upgradeCost(1, 1) > b.upgradeCost(1, 1))
    }

    @Test
    fun `max affordable is exactly what money allows`() {
        for (money in listOf(3.0, 4.0, 100.0, 12345.0, 9.87e9)) {
            val b = bakery(money)
            val n = b.maxAffordable(0)
            if (n > 0) assertTrue(b.upgradeCost(0, n) <= money)
            assertTrue(b.upgradeCost(0, n + 1) > money)
        }
    }

    @Test
    fun `buying spends money and fails without enough`() {
        val b = bakery(100.0)
        assertFalse(b.buy(2, 1))
        assertTrue(b.buy(1, 1))
        assertEquals(40.0, b.money, 1e-9)
        assertTrue(b.isUnlocked(1))
        assertFalse(b.buy(1, 0))
    }

    @Test
    fun `managers keep stations baking and handle fast ovens`() {
        val b = bakery(2_000.0)
        assertTrue(b.hireManager(0))
        assertFalse(b.hireManager(0))
        assertTrue(b.isRunning(0))
        val payouts = b.tick(6.0, now)
        // 6 s of 0.6 s batches = 10 batches in one payout.
        assertEquals(10.0, payouts.single().amount, 1e-9)
        assertFalse(b.tap(0), "managed stations don't need taps")
        assertEquals(1.0 / 0.6, b.incomePerSecond(now), 1e-9)
    }

    @Test
    fun `milestones double revenue`() {
        val b = bakery(0.0, levels = "25,0,0,0,0,0,0,0")
        assertEquals(2.0, b.milestoneMultiplier(25))
        assertEquals(1.0, b.milestoneMultiplier(24))
        assertEquals(8.0, b.milestoneMultiplier(100))
        assertEquals(50.0, b.revenuePerBatch(0, now))
        assertEquals(50, b.nextMilestone(0))
    }

    @Test
    fun `boost doubles income for 30 minutes and stacks to 4 hours`() {
        val b = bakery(2_000.0)
        b.hireManager(0)
        val normal = b.incomePerSecond(now)
        b.addBoost(now)
        assertTrue(b.isBoosted(now))
        assertEquals(normal * 2, b.incomePerSecond(now), 1e-9)
        assertFalse(b.isBoosted(now + Bakery.BOOST_MILLIS))
        repeat(20) { b.addBoost(now) }
        assertEquals(now + Bakery.MAX_BOOST_MILLIS, b.boostEndsAt)
    }

    @Test
    fun `offline earnings use managed stations and are capped`() {
        val b = bakery(2_000.0)
        b.hireManager(0)
        b.lastSeen = now
        val rate = b.incomePerSecond(now)
        assertEquals(rate * 60, b.offlineEarnings(now + 60_000), 1e-6)
        assertEquals(rate * Bakery.OFFLINE_CAP_SECONDS, b.offlineEarnings(now + 100L * 3600_000), 1e-6)
        assertEquals(0.0, b.offlineEarnings(now - 5))
        b.addBoost(now)
        // 30 boosted minutes count double.
        assertEquals(rate * (3600 + 1800), b.offlineEarnings(now + 3600_000), 1e-6)
    }

    @Test
    fun `franchise trades progress for stars`() {
        val b = bakery(5e9, levels = "40,10,5,0,0,0,0,0", managers = "1,1,0,0,0,0,0,0", earned = 4e9)
        assertEquals(20, b.starsAvailable())
        assertEquals(20, b.franchise())
        assertEquals(20, b.stars)
        assertEquals(0.0, b.money)
        assertEquals(1, b.levels[0])
        assertFalse(b.managers[0])
        assertEquals(2.0, b.globalMultiplier(now), 1e-9)
        assertThrows<IllegalArgumentException> { b.franchise() }
    }

    @Test
    fun `save and load round trip`() {
        val b = bakery(1e6)
        b.buy(1, 3)
        b.hireManager(0)
        b.tap(1)
        b.tick(1.0, now)
        b.addBoost(now)
        b.lastSeen = now
        val copy = Bakery.decode(b.encode())!!
        assertEquals(b.encode(), copy.encode())
        assertNull(Bakery.decode("nonsense"))
        assertNull(Bakery.decode(b.encode().replace("v1", "v9")))
    }

    @Test
    fun `a simulated player keeps growing`() {
        val b = Bakery()
        var t = now
        // Tap cookies, buy the cheapest useful upgrade, hire managers when possible.
        repeat(20 * 60 * 10) {
            for (i in 0 until Menu.stations.size) if (b.isUnlocked(i)) b.tap(i)
            b.tick(0.1, t)
            t += 100
            for (i in Menu.stations.indices) b.hireManager(i)
            val cheapest = Menu.stations.indices.minByOrNull { b.upgradeCost(it, 1) }!!
            b.buy(cheapest, 1)
        }
        assertTrue(b.levels.count { it > 0 } >= 4, "unlocked ${b.levels.toList()}")
        assertTrue(b.managers.count { it } >= 2)
        assertTrue(b.earnedThisRun > 1e5)
    }

    @Test
    fun `numbers are short and readable`() {
        assertEquals("0", Numbers.format(0.0))
        assertEquals("7.5", Numbers.format(7.5))
        assertEquals("999", Numbers.format(999.0))
        assertEquals("1.23K", Numbers.format(1234.0))
        assertEquals("45.6M", Numbers.format(45_678_901.0))
        assertEquals("999B", Numbers.format(999_999_999_999.0))
        assertEquals("1.00Dc", Numbers.format(1e33))
        assertEquals("1.00aa", Numbers.format(1e36))
        assertEquals("42s", Numbers.duration(42.0))
        assertEquals("1:05", Numbers.duration(65.0))
        assertEquals("1:00:00", Numbers.duration(3600.0))
    }
}
