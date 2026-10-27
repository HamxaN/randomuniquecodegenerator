package com.hamxanadeem.idlebakery.core

import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/** A batch came out of the oven. */
data class Payout(val station: Int, val amount: Double)

/**
 * The bakery's whole economy. Money is a Double because idle-game numbers grow far
 * past Long. Times are in seconds; clock values are epoch milliseconds.
 */
class Bakery {

    var money = 0.0
        private set
    /** Everything earned since the last franchise, which decides the stars on offer. */
    var earnedThisRun = 0.0
        private set
    var stars = 0
        private set
    var boostEndsAt = 0L
        private set
    var lastSeen = 0L

    private val stations = Menu.stations
    val levels = IntArray(stations.size)
    val managers = BooleanArray(stations.size)
    private val progress = DoubleArray(stations.size)
    private val running = BooleanArray(stations.size)

    init {
        // Everyone starts with one cookie oven.
        levels[0] = 1
    }

    fun isUnlocked(i: Int) = levels[i] > 0
    fun isRunning(i: Int) = running[i] || (managers[i] && levels[i] > 0)

    /** 0..1 progress of the current batch. */
    fun batchProgress(i: Int): Double = if (isRunning(i)) min(1.0, progress[i] / stations[i].seconds) else 0.0

    fun secondsLeft(i: Int): Double = if (isRunning(i)) max(0.0, stations[i].seconds - progress[i]) else stations[i].seconds

    // ---------------------------------------------------------------- income

    fun milestoneMultiplier(level: Int): Double = 2.0.pow(Menu.milestones.count { level >= it })

    fun isBoosted(now: Long) = now < boostEndsAt

    /** Stars (+5% each) and the ad boost (x2). */
    fun globalMultiplier(now: Long): Double = (1 + STAR_BONUS * stars) * (if (isBoosted(now)) BOOST_FACTOR else 1.0)

    fun revenuePerBatch(i: Int, now: Long): Double =
        stations[i].revenue * levels[i] * milestoneMultiplier(levels[i]) * globalMultiplier(now)

    /** Income per second from stations that run on their own. */
    fun incomePerSecond(now: Long): Double = stations.indices
        .filter { managers[it] && levels[it] > 0 }
        .sumOf { revenuePerBatch(it, now) / stations[it].seconds }

    /** The next milestone level for station [i], or null after the last one. */
    fun nextMilestone(i: Int): Int? = Menu.milestones.firstOrNull { it > levels[i] }

    // ---------------------------------------------------------------- time

    /** Tap a station to bake one batch by hand. */
    fun tap(i: Int): Boolean {
        if (levels[i] == 0 || running[i] || managers[i]) return false
        running[i] = true
        progress[i] = 0.0
        return true
    }

    fun tick(dt: Double, now: Long): List<Payout> {
        if (dt <= 0) return emptyList()
        val payouts = ArrayList<Payout>()
        for (i in stations.indices) {
            if (!isRunning(i)) continue
            progress[i] += dt
            val seconds = stations[i].seconds
            if (progress[i] < seconds) continue
            val batches = if (managers[i]) floor(progress[i] / seconds) else 1.0
            progress[i] = if (managers[i]) progress[i] - batches * seconds else 0.0
            if (!managers[i]) running[i] = false
            val amount = revenuePerBatch(i, now) * batches
            earn(amount)
            payouts += Payout(i, amount)
        }
        return payouts
    }

    private fun earn(amount: Double) {
        money += amount
        earnedThisRun += amount
    }

    /**
     * Money made while the app was closed: managed stations keep baking, up to
     * [OFFLINE_CAP_SECONDS]. The boost only counts for the part of the time it lasted.
     */
    fun offlineEarnings(now: Long): Double {
        if (lastSeen <= 0 || now <= lastSeen) return 0.0
        val seconds = min((now - lastSeen) / 1000.0, OFFLINE_CAP_SECONDS)
        val boostedSeconds = ((boostEndsAt - lastSeen) / 1000.0).coerceIn(0.0, seconds)
        // Long.MAX_VALUE is always after the boost, so this is the unboosted rate.
        val base = incomePerSecond(Long.MAX_VALUE)
        return base * (seconds + boostedSeconds * (BOOST_FACTOR - 1))
    }

    fun collectOffline(amount: Double) {
        require(amount >= 0) { "Amount must not be negative" }
        earn(amount)
    }

    // ---------------------------------------------------------------- buying

    /** Cost of the next [count] levels of station [i]. */
    fun upgradeCost(i: Int, count: Int): Double {
        val s = stations[i]
        val start = s.baseCost * s.costGrowth.pow(levels[i])
        return start * (s.costGrowth.pow(count) - 1) / (s.costGrowth - 1)
    }

    /** How many levels of station [i] the bakery can afford right now. */
    fun maxAffordable(i: Int): Int {
        val s = stations[i]
        val start = s.baseCost * s.costGrowth.pow(levels[i])
        if (money < start) return 0
        val n = floor(ln(money * (s.costGrowth - 1) / start + 1) / ln(s.costGrowth)).toInt()
        // Guard against floating-point edge cases.
        var count = max(0, n)
        while (count > 0 && upgradeCost(i, count) > money) count--
        return count
    }

    fun buy(i: Int, count: Int): Boolean {
        if (count <= 0) return false
        val cost = upgradeCost(i, count)
        if (cost > money) return false
        money -= cost
        levels[i] += count
        return true
    }

    fun managerCost(i: Int): Double = stations[i].managerCost

    fun canHire(i: Int) = levels[i] > 0 && !managers[i] && money >= managerCost(i)

    fun hireManager(i: Int): Boolean {
        if (!canHire(i)) return false
        money -= managerCost(i)
        managers[i] = true
        if (running[i]) running[i] = false
        return true
    }

    // ---------------------------------------------------------------- boost and franchise

    /** Rewarded ad: 30 more minutes of double income, stacking up to 4 hours. */
    fun addBoost(now: Long) {
        val from = max(now, boostEndsAt)
        boostEndsAt = min(from + BOOST_MILLIS, now + MAX_BOOST_MILLIS)
    }

    /** Stars a franchise would award now. */
    fun starsAvailable(): Int = max(0, floor(sqrt(earnedThisRun / STAR_DIVISOR)).toInt())

    /** Start over in a new city, keeping stars. Returns the stars gained. */
    fun franchise(): Int {
        val gained = starsAvailable()
        require(gained > 0) { "Nothing to gain yet" }
        stars += gained
        money = 0.0
        earnedThisRun = 0.0
        levels.fill(0)
        levels[0] = 1
        managers.fill(false)
        progress.fill(0.0)
        running.fill(false)
        return gained
    }

    // ---------------------------------------------------------------- saving

    fun encode(): String = listOf(
        "v1",
        money.toString(),
        earnedThisRun.toString(),
        stars.toString(),
        boostEndsAt.toString(),
        lastSeen.toString(),
        levels.joinToString(","),
        managers.joinToString(",") { if (it) "1" else "0" },
        progress.joinToString(","),
        running.joinToString(",") { if (it) "1" else "0" },
    ).joinToString(";")

    companion object {
        const val STAR_BONUS = 0.05
        const val STAR_DIVISOR = 1e7
        const val BOOST_FACTOR = 2.0
        const val BOOST_MILLIS = 30 * 60 * 1000L
        const val MAX_BOOST_MILLIS = 4 * 60 * 60 * 1000L
        const val OFFLINE_CAP_SECONDS = 4 * 60 * 60.0

        fun decode(text: String): Bakery? {
            val p = text.split(';')
            if (p.size != 10 || p[0] != "v1") return null
            val n = Menu.stations.size
            val b = Bakery()
            b.money = p[1].toDoubleOrNull()?.takeIf { it.isFinite() && it >= 0 } ?: return null
            b.earnedThisRun = p[2].toDoubleOrNull()?.takeIf { it.isFinite() && it >= 0 } ?: return null
            b.stars = p[3].toIntOrNull()?.takeIf { it >= 0 } ?: return null
            b.boostEndsAt = p[4].toLongOrNull() ?: return null
            b.lastSeen = p[5].toLongOrNull() ?: return null
            val levels = p[6].split(',').map { it.toIntOrNull() ?: return null }
            val managers = p[7].split(',')
            val progress = p[8].split(',').map { it.toDoubleOrNull() ?: return null }
            val running = p[9].split(',')
            if (listOf(levels.size, managers.size, progress.size, running.size).any { it != n }) return null
            if (levels.any { it < 0 }) return null
            for (i in 0 until n) {
                b.levels[i] = levels[i]
                b.managers[i] = managers[i] == "1"
                b.progress[i] = progress[i].coerceAtLeast(0.0)
                b.running[i] = running[i] == "1"
            }
            return b
        }
    }
}
