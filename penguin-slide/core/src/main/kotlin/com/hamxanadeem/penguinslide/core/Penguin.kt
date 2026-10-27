package com.hamxanadeem.penguinslide.core

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Things that happen during a physics step, for sounds and effects. */
sealed interface SlideEvent {
    data object TakeOff : SlideEvent
    data object PerfectLanding : SlideEvent
    data object GoodLanding : SlideEvent
    data object Wipeout : SlideEvent
    data class Flips(val count: Int) : SlideEvent
}

/**
 * The penguin's physics. On the ground it slides along the slope (diving adds
 * downhill force); over a crest it launches into the air. Holding in the air spins
 * it backwards; landing upright and parallel to the slope gives a speed boost,
 * landing on its head is a wipeout.
 */
class Penguin(private val terrain: Terrain) {

    var x = 0.0
        private set
    var y = terrain.heightAt(0.0)
        private set
    var vx = MIN_SPEED
        private set
    var vy = 0.0
        private set
    var onGround = true
        private set

    /** Body angle in radians, counter-clockwise. On the ground it follows the slope. */
    var rotation = 0.0
        private set
    private var spun = 0.0

    /** Extra top speed while in fever mode. */
    var speedBonus = 1.0

    val speed: Double get() = hypot(vx, vy)

    fun step(dt: Double, holding: Boolean, events: MutableList<SlideEvent>) {
        if (onGround) stepGround(dt, holding, events) else stepAir(dt, holding, events)
    }

    private fun stepGround(dt: Double, diving: Boolean, events: MutableList<SlideEvent>) {
        val angle = atan(terrain.slopeAt(x))
        var s = hypot(vx, vy)
        // Gravity pulls along the slope; diving presses harder so downhill is faster.
        val pull = if (diving) GRAVITY * DIVE_FACTOR else GRAVITY
        s += (-pull * sin(angle) - DRAG * s) * dt
        s = s.coerceIn(MIN_SPEED, MAX_SPEED * speedBonus)
        vx = s * cos(angle)
        vy = s * sin(angle)
        rotation = angle

        // On a rounded crest the snow curves away under the penguin. If gravity can't
        // bend its path that tightly (v²·κ > g·cosθ) it leaves the ground and flies.
        val slope = terrain.slopeAt(x)
        val bend = -terrain.curvatureAt(x) / Math.pow(1 + slope * slope, 1.5)
        val nextX = x + vx * dt
        if (!diving && bend > 0 && s * s * bend > GRAVITY * cos(angle)) {
            onGround = false
            spun = 0.0
            x = nextX
            y += vy * dt
            events += SlideEvent.TakeOff
        } else {
            x = nextX
            y = terrain.heightAt(nextX)
        }
    }

    private fun stepAir(dt: Double, spinning: Boolean, events: MutableList<SlideEvent>) {
        vy -= GRAVITY * dt
        x += vx * dt
        y += vy * dt
        val flight = atan2(vy, vx)
        if (spinning) {
            rotation += SPIN_SPEED * dt
            spun += SPIN_SPEED * dt
        } else {
            // A gentle assist: once nearly lined up with the flight path, settle into it.
            val diff = wrap(flight - rotation)
            if (abs(diff) < ASSIST_ANGLE) rotation += diff * min(1.0, ASSIST_RATE * dt)
        }

        val groundY = terrain.heightAt(x)
        if (y <= groundY) land(groundY, events)
    }

    private fun land(groundY: Double, events: MutableList<SlideEvent>) {
        y = groundY
        onGround = true
        val slope = atan(terrain.slopeAt(x))
        val tx = cos(slope)
        val ty = sin(slope)
        val alongSlope = max(0.0, vx * tx + vy * ty)
        val upright = abs(wrap(rotation - slope)) < UPRIGHT_ANGLE
        val flips = floor((spun + UPRIGHT_ANGLE) / (2 * PI)).toInt()

        val newSpeed = when {
            !upright -> {
                events += SlideEvent.Wipeout
                alongSlope * 0.35
            }
            abs(wrap(atan2(vy, vx) - slope)) < PERFECT_ANGLE -> {
                events += SlideEvent.PerfectLanding
                alongSlope + PERFECT_BOOST
            }
            else -> {
                events += SlideEvent.GoodLanding
                alongSlope * 0.85
            }
        }
        if (upright && flips > 0) events += SlideEvent.Flips(flips)
        val s = newSpeed.coerceIn(MIN_SPEED, MAX_SPEED * speedBonus)
        vx = s * tx
        vy = s * ty
        rotation = slope
        spun = 0.0
    }

    /** Height above the ground right now (0 when sliding). */
    val altitude: Double get() = y - terrain.heightAt(x)

    companion object {
        const val GRAVITY = 22.0
        const val DIVE_FACTOR = 2.4
        const val DRAG = 0.015
        const val MIN_SPEED = 5.0
        const val MAX_SPEED = 55.0
        const val SPIN_SPEED = 2 * PI * 1.3
        const val UPRIGHT_ANGLE = 0.6
        const val PERFECT_ANGLE = 0.3
        const val PERFECT_BOOST = 4.0
        const val ASSIST_ANGLE = PI / 4
        const val ASSIST_RATE = 6.0

        /** Wraps an angle to -PI..PI. */
        fun wrap(angle: Double): Double {
            var a = angle % (2 * PI)
            if (a > PI) a -= 2 * PI
            if (a < -PI) a += 2 * PI
            return a
        }
    }
}
