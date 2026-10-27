package com.hamxanadeem.penguinslide.core

import kotlin.math.hypot
import kotlin.math.max
import kotlin.random.Random

/** Something the screen should celebrate. */
sealed interface RunEvent {
    data object TakeOff : RunEvent
    data object PerfectLanding : RunEvent
    data object GoodLanding : RunEvent
    data object Wipeout : RunEvent
    data class Flips(val count: Int, val points: Int) : RunEvent
    data class FishCaught(val fish: Fish) : RunEvent
    data class Checkpoint(val number: Int, val bonusSeconds: Double) : RunEvent
    data object FeverStart : RunEvent
    data object FeverEnd : RunEvent
    data object TimeUp : RunEvent
}

class Fish(val id: Int, val x: Double, val y: Double) {
    var caught = false
        internal set
}

/**
 * One slide: the penguin, the clock (the sun is setting), checkpoints that add time,
 * fish to collect, perfect-landing streaks that trigger fever mode, and the score.
 */
class Run(seed: Long) {

    val terrain = Terrain(seed)
    val penguin = Penguin(terrain)
    private val random = Random(seed xor 0x5EED)

    var timeLeft = START_SECONDS
        private set
    var elapsed = 0.0
        private set
    var fishCaught = 0
        private set
    var flips = 0
        private set
    var perfectLandings = 0
        private set
    var perfectStreak = 0
        private set
    var feverUntil = 0.0
        private set
    var checkpointsPassed = 0
        private set
    var revived = false
        private set

    val isOver: Boolean get() = timeLeft <= 0.0
    val canRevive: Boolean get() = isOver && !revived
    val inFever: Boolean get() = elapsed < feverUntil

    val distance: Int get() = max(0.0, penguin.x).toInt()
    val score: Int get() = distance + flips * FLIP_POINTS + perfectLandings * PERFECT_POINTS + fishCaught * FISH_POINTS

    val nextCheckpointX: Double get() = (checkpointsPassed + 1) * CHECKPOINT_SPACING

    private val fish = ArrayList<Fish>()
    private var fishGeneratedTo = 30.0
    private var nextFishId = 0

    /** Fish near [from]..[to] for drawing. */
    fun fishBetween(from: Double, to: Double): List<Fish> {
        generateFish(to)
        return fish.filter { it.x in from..to && !it.caught }
    }

    private fun generateFish(to: Double) {
        if (fishGeneratedTo >= to) return
        // Arcs of fish over some peaks reward big jumps.
        for ((px, ph) in terrain.keyPointsBetween(fishGeneratedTo, to + 60)) {
            if (px <= fishGeneratedTo) continue
            if (random.nextFloat() < 0.6f) {
                val lift = 3.0 + random.nextDouble() * 4.0
                for (i in -2..2) {
                    val fx = px + i * 2.2
                    fish += Fish(nextFishId++, fx, ph + lift - i * i * 0.35)
                }
            }
        }
        fishGeneratedTo = to + 60
    }

    fun update(dt: Double, holding: Boolean): List<RunEvent> {
        val events = ArrayList<RunEvent>()
        if (isOver) return events
        var remaining = dt.coerceAtMost(0.1)
        val slideEvents = ArrayList<SlideEvent>()
        while (remaining > 0) {
            val step = minOf(STEP, remaining)
            remaining -= step
            penguin.speedBonus = if (inFever) FEVER_SPEED_BONUS else 1.0
            slideEvents.clear()
            penguin.step(step, holding, slideEvents)
            slideEvents.forEach { handle(it, events) }
            elapsed += step
            timeLeft -= step
            if (feverUntil > 0 && elapsed >= feverUntil && elapsed - step < feverUntil) events += RunEvent.FeverEnd
            catchFish(events)
            passCheckpoints(events)
            if (timeLeft <= 0.0) {
                timeLeft = 0.0
                events += RunEvent.TimeUp
                break
            }
        }
        return events
    }

    private fun handle(event: SlideEvent, events: MutableList<RunEvent>) {
        when (event) {
            SlideEvent.TakeOff -> events += RunEvent.TakeOff
            SlideEvent.GoodLanding -> {
                perfectStreak = 0
                events += RunEvent.GoodLanding
            }
            SlideEvent.Wipeout -> {
                perfectStreak = 0
                if (inFever) {
                    feverUntil = elapsed
                    events += RunEvent.FeverEnd
                }
                events += RunEvent.Wipeout
            }
            SlideEvent.PerfectLanding -> {
                perfectLandings++
                perfectStreak++
                events += RunEvent.PerfectLanding
                if (perfectStreak >= FEVER_STREAK) {
                    if (!inFever) events += RunEvent.FeverStart
                    feverUntil = elapsed + FEVER_SECONDS
                }
            }
            is SlideEvent.Flips -> {
                flips += event.count
                events += RunEvent.Flips(event.count, event.count * FLIP_POINTS)
            }
        }
    }

    private fun catchFish(events: MutableList<RunEvent>) {
        generateFish(penguin.x + 40)
        for (f in fish) {
            if (f.caught || f.x < penguin.x - 3 || f.x > penguin.x + 3) continue
            if (hypot(f.x - penguin.x, f.y - (penguin.y + 0.6)) < CATCH_RADIUS) {
                f.caught = true
                fishCaught++
                events += RunEvent.FishCaught(f)
            }
        }
        // Forget fish far behind to keep the list small.
        if (fish.size > 200) fish.removeAll { it.x < penguin.x - 50 }
    }

    private fun passCheckpoints(events: MutableList<RunEvent>) {
        while (penguin.x >= nextCheckpointX) {
            checkpointsPassed++
            val bonus = max(MIN_CHECKPOINT_BONUS, CHECKPOINT_BONUS - checkpointsPassed * 1.5)
            timeLeft += bonus
            events += RunEvent.Checkpoint(checkpointsPassed, bonus)
        }
    }

    /** Second chance (rewarded ad): more time on the clock, once per run. */
    fun revive() {
        check(canRevive) { "Revive is only allowed once, after the time runs out" }
        revived = true
        timeLeft = REVIVE_SECONDS
    }

    companion object {
        const val STEP = 1.0 / 240.0
        const val START_SECONDS = 45.0
        const val CHECKPOINT_SPACING = 500.0
        const val CHECKPOINT_BONUS = 20.0
        const val MIN_CHECKPOINT_BONUS = 8.0
        const val REVIVE_SECONDS = 15.0
        const val FEVER_STREAK = 3
        const val FEVER_SECONDS = 6.0
        const val FEVER_SPEED_BONUS = 1.25
        const val CATCH_RADIUS = 1.6
        const val FLIP_POINTS = 100
        const val PERFECT_POINTS = 25
        const val FISH_POINTS = 5
    }
}
