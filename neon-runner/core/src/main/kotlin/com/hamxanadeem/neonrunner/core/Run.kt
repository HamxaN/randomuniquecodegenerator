package com.hamxanadeem.neonrunner.core

import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.random.Random

/** What stands in a lane. */
enum class ObstacleKind {
    /** Low barrier: jump over it. */
    BARRIER,
    /** Laser beam at head height: slide under it. */
    BEAM,
    /** Solid wall: change lanes. */
    WALL,
}

enum class PowerKind { MAGNET, SHIELD, BOOST }

class Obstacle(val z: Double, val lane: Int, val kind: ObstacleKind)

/** An energy orb. High orbs need a jump. */
class Orb(val z: Double, val lane: Int, val high: Boolean) {
    var taken = false
}

class PowerUp(val z: Double, val lane: Int, val kind: PowerKind) {
    var taken = false
}

sealed interface RunEvent {
    data class OrbTaken(val lane: Int) : RunEvent
    data class PowerTaken(val kind: PowerKind) : RunEvent
    data object ShieldBroke : RunEvent
    data object Jumped : RunEvent
    data object Slid : RunEvent
    data object LaneChanged : RunEvent
    data class Crashed(val kind: ObstacleKind) : RunEvent
    data class Milestone(val metres: Int) : RunEvent
}

/**
 * One run down the neon track. The runner moves forward along z (metres) in one of
 * three lanes. Rows of obstacles are generated ahead so there is always a way
 * through: a free lane, or a barrier to jump or a beam to slide under.
 */
class Run(seed: Long = 1) {

    private val random = Random(seed)

    val obstacles = ArrayList<Obstacle>()
    val orbs = ArrayList<Orb>()
    val powerUps = ArrayList<PowerUp>()

    /** Distance run, in metres. */
    var z = 0.0
        private set
    var speed = START_SPEED
        private set
    var lane = 1
        private set
    /** Smoothed lane position for drawing, 0..2. */
    var laneX = 1.0
        private set
    /** Seconds into the current jump, or -1. */
    var jumpTime = -1.0
        private set
    var slideTime = -1.0
        private set
    var alive = true
        private set
    var orbsTaken = 0
        private set
    var magnetLeft = 0.0
        private set
    var shieldLeft = 0.0
        private set
    var boostLeft = 0.0
        private set
    var revived = false
        private set
    /** Seconds of safety after a revive. */
    var graceLeft = 0.0
        private set

    private var generatedTo = 30.0
    private var prevFree = listOf(1)
    private var lastMilestone = 0
    private val events = ArrayList<RunEvent>()

    val score: Int get() = z.toInt() + orbsTaken * ORB_POINTS
    val jumping: Boolean get() = jumpTime >= 0
    val sliding: Boolean get() = slideTime >= 0

    /** Height of the runner's feet above the track, in metres. */
    val height: Double
        get() {
            if (!jumping) return 0.0
            val k = jumpTime / JUMP_SECONDS
            return 4 * JUMP_HEIGHT * k * (1 - k)
        }

    init {
        generate()
    }

    // ---------------------------------------------------------------- input

    fun left() = moveLane(-1)

    fun right() = moveLane(1)

    private fun moveLane(dir: Int) {
        if (!alive) return
        val target = (lane + dir).coerceIn(0, LANES - 1)
        if (target != lane) {
            lane = target
            events += RunEvent.LaneChanged
        }
    }

    fun jump() {
        if (!alive || jumping) return
        slideTime = -1.0
        jumpTime = 0.0
        events += RunEvent.Jumped
    }

    fun slide() {
        if (!alive) return
        // Sliding cuts a jump short: drop straight down.
        jumpTime = -1.0
        slideTime = 0.0
        events += RunEvent.Slid
    }

    /** Continues after a crash (a rewarded ad); clears the obstacles just ahead. */
    fun revive() {
        if (alive || revived) return
        alive = true
        revived = true
        graceLeft = 2.0
        obstacles.removeAll { it.z < z + 25 }
        speed = maxOf(START_SPEED, speed * 0.85)
    }

    // ---------------------------------------------------------------- simulation

    fun update(dt: Double): List<RunEvent> {
        if (alive) step(dt.coerceAtMost(0.05))
        val out = ArrayList(events)
        events.clear()
        return out
    }

    private fun step(dt: Double) {
        // Speed creeps up with distance; a boost adds a burst.
        speed = min(MAX_SPEED, START_SPEED + z * ACCELERATION)
        val v = if (boostLeft > 0) speed * 1.6 else speed
        val prevZ = z
        z += v * dt

        // Ease towards the chosen lane.
        val diff = lane - laneX
        laneX += diff * min(1.0, dt * LANE_SNAP)
        if (abs(lane - laneX) < 0.01) laneX = lane.toDouble()

        if (jumping) {
            jumpTime += dt
            if (jumpTime >= JUMP_SECONDS) jumpTime = -1.0
        }
        if (sliding) {
            slideTime += dt
            if (slideTime >= SLIDE_SECONDS) slideTime = -1.0
        }
        magnetLeft = (magnetLeft - dt).coerceAtLeast(0.0)
        shieldLeft = (shieldLeft - dt).coerceAtLeast(0.0)
        boostLeft = (boostLeft - dt).coerceAtLeast(0.0)
        graceLeft = (graceLeft - dt).coerceAtLeast(0.0)

        collide(prevZ, z)

        val metres = (z / 250).toInt() * 250
        if (metres > lastMilestone) {
            lastMilestone = metres
            events += RunEvent.Milestone(metres)
        }

        generate()
        obstacles.removeAll { it.z < z - 5 }
        orbs.removeAll { it.z < z - 5 || it.taken }
        powerUps.removeAll { it.z < z - 5 || it.taken }
    }

    /** The lane the runner is mostly in right now (it can be between two lanes while moving). */
    private val bodyLane: Int get() = laneX.roundToInt()

    private fun collide(fromZ: Double, toZ: Double) {
        val myLane = bodyLane
        for (o in obstacles) {
            if (o.z <= fromZ || o.z > toZ) continue
            if (o.lane != myLane) continue
            val clear = when (o.kind) {
                ObstacleKind.BARRIER -> height > BARRIER_HEIGHT
                ObstacleKind.BEAM -> sliding
                ObstacleKind.WALL -> false
            }
            if (clear || graceLeft > 0 || boostLeft > 0) continue
            if (shieldLeft > 0) {
                shieldLeft = 0.0
                events += RunEvent.ShieldBroke
                continue
            }
            alive = false
            events += RunEvent.Crashed(o.kind)
            return
        }
        for (orb in orbs) {
            if (orb.taken || orb.z > toZ + (if (magnetLeft > 0) MAGNET_REACH else 0.0) || orb.z < fromZ - 1) continue
            val reach = magnetLeft > 0 || (orb.lane == myLane && (orb.high == (height > 0.8)))
            if (reach && (magnetLeft > 0 || orb.z <= toZ)) {
                orb.taken = true
                orbsTaken++
                events += RunEvent.OrbTaken(orb.lane)
            }
        }
        for (p in powerUps) {
            if (p.taken || p.z <= fromZ || p.z > toZ || p.lane != myLane) continue
            p.taken = true
            when (p.kind) {
                PowerKind.MAGNET -> magnetLeft = POWER_SECONDS
                PowerKind.SHIELD -> shieldLeft = POWER_SECONDS * 2
                PowerKind.BOOST -> boostLeft = BOOST_SECONDS
            }
            events += RunEvent.PowerTaken(p.kind)
        }
    }

    // ---------------------------------------------------------------- track generation

    /** Fills the track up to [AHEAD] metres in front with rows of obstacles and orbs. */
    private fun generate() {
        while (generatedTo < z + AHEAD) {
            val difficulty = min(1.0, generatedTo / 3000.0)
            // Rows get closer as the run goes on, but never closer than the runner can react to.
            val speedThere = min(MAX_SPEED, START_SPEED + generatedTo * ACCELERATION)
            val gap = maxOf(ROW_GAP_MAX - (ROW_GAP_MAX - ROW_GAP_MIN) * difficulty, speedThere * REACTION_SECONDS) + random.nextDouble() * 6
            generatedTo += gap
            row(generatedTo, difficulty)
        }
    }

    private fun row(rz: Double, difficulty: Double) {
        // Choose what each lane holds, keeping at least one lane passable.
        val kinds = arrayOfNulls<ObstacleKind>(LANES)
        val filled = when {
            random.nextDouble() < 0.25 + difficulty * 0.35 -> 2
            else -> 1
        }
        val lanes = (0 until LANES).shuffled(random).take(filled)
        for (l in lanes) {
            kinds[l] = when (random.nextInt(if (difficulty > 0.15) 3 else 2)) {
                0 -> ObstacleKind.BARRIER
                1 -> ObstacleKind.BEAM
                else -> ObstacleKind.WALL
            }
        }
        // Keep a free lane next to (or in) one that was free in the row before, so you
        // never have to cross two lanes in a hurry.
        val reachable = (0 until LANES).filter { l -> kinds[l] == null && prevFree.any { abs(it - l) <= 1 } }
        if (reachable.isEmpty()) {
            val near = (0 until LANES).filter { l -> prevFree.any { abs(it - l) <= 1 } }
            kinds[near[random.nextInt(near.size)]] = null
        }
        for (l in 0 until LANES) kinds[l]?.let { obstacles += Obstacle(rz, l, it) }
        prevFree = (0 until LANES).filter { kinds[it] == null }

        // A line of orbs leading up to the row in a free lane, or over a barrier.
        val free = (0 until LANES).filter { kinds[it] == null }
        val orbLane = if (free.isNotEmpty()) free[random.nextInt(free.size)] else (0 until LANES).first { kinds[it] != ObstacleKind.WALL }
        val overBarrier = kinds[orbLane] == ObstacleKind.BARRIER
        val count = 3 + random.nextInt(4)
        for (i in 0 until count) {
            val oz = rz - 2 - (count - 1 - i) * 2.2
            if (oz > z + 8) orbs += Orb(oz, orbLane, high = overBarrier && i == count - 1)
        }
        // Now and then a power-up in a free lane, between rows.
        if (free.isNotEmpty() && random.nextDouble() < POWER_CHANCE) {
            val kind = PowerKind.entries[random.nextInt(PowerKind.entries.size)]
            powerUps += PowerUp(rz - ROW_GAP_MIN / 2, free[random.nextInt(free.size)], kind)
        }
    }

    companion object {
        const val LANES = 3
        const val START_SPEED = 16.0
        const val MAX_SPEED = 42.0
        const val ACCELERATION = 0.006
        const val LANE_SNAP = 14.0
        const val JUMP_SECONDS = 0.62
        const val JUMP_HEIGHT = 1.6
        const val SLIDE_SECONDS = 0.62
        const val BARRIER_HEIGHT = 0.55
        const val AHEAD = 120.0
        const val ROW_GAP_MIN = 14.0
        const val ROW_GAP_MAX = 26.0
        const val REACTION_SECONDS = 0.55
        const val ORB_POINTS = 5
        const val POWER_CHANCE = 0.08
        const val POWER_SECONDS = 8.0
        const val BOOST_SECONDS = 3.0
        const val MAGNET_REACH = 6.0
    }
}
