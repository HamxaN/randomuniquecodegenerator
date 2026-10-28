package com.hamxanadeem.wigglewars.core

import kotlin.math.PI

class Worm(val id: Int, val team: Int, val name: String, var x: Double, var y: Double) {
    var vx = 0.0
    var vy = 0.0
    var health = START_HEALTH
    var alive = true
    var onGround = false
    /** +1 facing right, -1 facing left. */
    var facing = 1
    /** Aim above (-) or below (+) horizontal, in radians, from -PI/2 to PI/2. */
    var aim = -PI / 6
    internal var fallStartY = y
    internal var stuckSteps = 0

    /** World-space aim direction. */
    val aimX: Double get() = cos(aim) * facing
    val aimY: Double get() = sin(aim)

    companion object {
        const val START_HEALTH = 100
        const val RADIUS = 7.0
    }
}

data class Team(val id: Int, val name: String, val cpu: Boolean, val worms: List<Worm>) {
    val alive: Boolean get() = worms.any { it.alive }
    val totalHealth: Int get() = worms.filter { it.alive }.sumOf { it.health }
}
