package com.hamxanadeem.penguinslide.core

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Endless snowy hills, generated lazily from a seed. Hills alternate between peaks
 * and valleys joined by smooth cosine curves, and grow taller and wider with distance.
 * Units are metres; x grows to the right and height grows upwards.
 */
class Terrain(seed: Long) {

    private val random = Random(seed)
    private val xs = ArrayList<Double>()
    private val hs = ArrayList<Double>()

    init {
        // Start on a high peak so the first slide is downhill.
        xs += -40.0; hs += START_HEIGHT
        xs += 0.0; hs += START_HEIGHT
    }

    private fun ensure(x: Double) {
        while (xs.last() < x + LOOKAHEAD) {
            val lastX = xs.last()
            val distance = maxOf(0.0, lastX)
            val difficulty = min(1.0, distance / 3000.0)
            val width = 16.0 + random.nextDouble() * 10.0 + difficulty * 14.0
            val amplitude = 3.0 + difficulty * 6.0 + random.nextDouble() * 2.5
            val goingDown = xs.size % 2 == 0
            val height = if (goingDown) BASE_HEIGHT - amplitude else BASE_HEIGHT + amplitude * 0.8
            xs += lastX + width
            hs += height
        }
    }

    private fun segment(x: Double): Int {
        ensure(x)
        var lo = 0
        var hi = xs.size - 2
        while (lo < hi) {
            val mid = (lo + hi + 1) / 2
            if (xs[mid] <= x) lo = mid else hi = mid - 1
        }
        return lo
    }

    fun heightAt(x: Double): Double {
        if (x <= xs[0]) return hs[0]
        val i = segment(x)
        val t = (x - xs[i]) / (xs[i + 1] - xs[i])
        return hs[i] + (hs[i + 1] - hs[i]) * (1 - cos(PI * t)) / 2
    }

    /** dh/dx: positive means uphill to the right. */
    fun slopeAt(x: Double): Double {
        if (x <= xs[0]) return 0.0
        val i = segment(x)
        val width = xs[i + 1] - xs[i]
        val t = (x - xs[i]) / width
        return (hs[i + 1] - hs[i]) * PI / 2 * sin(PI * t) / width
    }

    /** d²h/dx²: negative on the rounded tops of hills. */
    fun curvatureAt(x: Double): Double {
        if (x <= xs[0]) return 0.0
        val i = segment(x)
        val width = xs[i + 1] - xs[i]
        val t = (x - xs[i]) / width
        return (hs[i + 1] - hs[i]) * PI * PI / 2 * cos(PI * t) / (width * width)
    }

    /** Peak and valley points between [from] and [to], used to place fish over the hills. */
    fun keyPointsBetween(from: Double, to: Double): List<Pair<Double, Double>> {
        ensure(to)
        return xs.indices.filter { xs[it] in from..to }.map { xs[it] to hs[it] }
    }

    companion object {
        const val START_HEIGHT = 14.0
        const val BASE_HEIGHT = 6.0
        private const val LOOKAHEAD = 200.0
    }
}
