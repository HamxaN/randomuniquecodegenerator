package com.hamxanadeem.wigglewars.core

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/**
 * Where a match is fought. Each arena has its own land shape and can change the
 * physics: the moon has low gravity and no wind; the caverns have a rock roof.
 */
enum class Arena(
    val displayName: String,
    val tagline: String,
    val gravity: Double = 1.0,
    val windScale: Double = 1.0,
    /** Solid rock overhead: crates and air strikes can't come from the sky. */
    val roof: Boolean = false,
    /** Draw dark dirt behind dug-out ground. Off where the land floats in the sky. */
    val backdrop: Boolean = true,
) {
    HILLS("Green Hills", "Rolling meadows with hidden caves"),
    DUNES("Dune Canyon", "A deep canyon between desert mesas"),
    ISLANDS("Tropical Islands", "Island hopping — mind the sea!"),
    FORTRESS("Castle Clash", "Two castles and a rickety bridge"),
    CAVERN("Crystal Caverns", "Underground: no air strikes, no crates from the sky", roof = true),
    SKY("Sky Islands", "Floating islands high above the waves", windScale = 1.2, backdrop = false),
    SNOW("Frozen Peaks", "Jagged mountains and strong winds", windScale = 1.4),
    VOLCANO("Lava Peak", "A huge volcano over a lake of lava"),
    MOON("Moon Base", "Low gravity, no wind. Shots fly far!", gravity = 0.5, windScale = 0.0),
    CANDY("Candy Land", "Bubbly sweets and lollipops"),
    ;

    fun generate(seed: Long, width: Int = 2000, height: Int = 1000): Terrain {
        val s = Sculptor(Terrain(width, height), Random(seed))
        when (this) {
            HILLS -> s.hills()
            DUNES -> s.dunes()
            ISLANDS -> s.islands()
            FORTRESS -> s.fortress()
            CAVERN -> s.cavern()
            SKY -> s.sky()
            SNOW -> s.snow()
            VOLCANO -> s.volcano()
            MOON -> s.moon()
            CANDY -> s.candy()
        }
        return s.t
    }
}

/** Shapes the land for each arena. Uses StrictMath helpers so every phone builds the same map. */
internal class Sculptor(val t: Terrain, val r: Random) {
    private val w = t.width
    private val h = t.height

    // ------------------------------------------------------------ building blocks

    private fun fillColumns(tops: DoubleArray) {
        for (x in 0 until w) {
            val start = tops[x].toInt().coerceIn(0, h)
            for (y in start until h) t.set(x, y, true)
        }
    }

    /** Extra depth near both ends so the land falls into the sea there. */
    private fun edgeDrop(x: Int, margin: Double = 0.12): Double {
        val u = x.toDouble() / w
        val edge = min(1.0, min(u, 1 - u) / margin)
        return (1 - edge) * h * 0.6
    }

    private fun ellipse(cx: Double, cy: Double, rx: Double, ry: Double, solid: Boolean) {
        for (y in (cy - ry).toInt()..(cy + ry).toInt()) for (x in (cx - rx).toInt()..(cx + rx).toInt()) {
            val dx = (x - cx) / rx
            val dy = (y - cy) / ry
            if (dx * dx + dy * dy <= 1) t.set(x, y, solid)
        }
    }

    private fun rect(left: Int, top: Int, right: Int, bottom: Int, solid: Boolean) {
        for (y in top until bottom) for (x in left until right) t.set(x, y, solid)
    }

    private fun waves(count: Int, spread: Double): List<Triple<Double, Double, Double>> =
        List(count) { Triple(0.5 + r.nextDouble() * spread * (it + 1), r.nextDouble() * 2 * PI, 0.4 / (it + 1)) }

    private fun waveSum(x: Int, list: List<Triple<Double, Double, Double>>): Double {
        val u = x.toDouble() / w
        var v = 0.0
        for ((freq, phase, weight) in list) v += sin(u * freq * 2 * PI + phase) * weight
        return v
    }

    private fun caves(count: Int, minDepth: Double = 60.0) {
        repeat(count) {
            val cx = w * (0.15 + r.nextDouble() * 0.7)
            val ground = t.groundBelow(cx.toInt()) ?: return@repeat
            val cy = ground + minDepth + r.nextDouble() * 140
            if (cy > t.waterY - 40) return@repeat
            ellipse(cx, cy, 40 + r.nextDouble() * 90, 22 + r.nextDouble() * 30, solid = false)
        }
    }

    private fun ledges(count: Int, top: Double = 0.15, spread: Double = 0.2) {
        repeat(count) {
            val cx = w * (0.15 + r.nextDouble() * 0.7)
            val cy = h * (top + r.nextDouble() * spread)
            val rx = 50 + r.nextDouble() * 70
            val ry = 10 + r.nextDouble() * 10
            for (y in (cy - ry).toInt()..(cy + ry * 1.8).toInt()) for (x in (cx - rx).toInt()..(cx + rx).toInt()) {
                val dx = (x - cx) / rx
                val dy = if (y < cy) (y - cy) / ry else (y - cy) / (ry * 1.8)
                if (dx * dx + dy * dy <= 1) t.set(x, y, true)
            }
        }
    }

    // ------------------------------------------------------------ arenas

    /** Rolling islands with caves and tunnels; the original map. */
    fun hills() {
        val list = waves(5, 3.0)
        val canyon = if (r.nextBoolean()) w * (0.4 + r.nextDouble() * 0.2) else -1.0
        val canyonWidth = 50 + r.nextDouble() * 60
        val tops = DoubleArray(w) { x ->
            var top = h * 0.5 - waveSum(x, list) * h * 0.22 + edgeDrop(x)
            if (canyon > 0 && abs(x - canyon) < canyonWidth) {
                val k = 1 - abs(x - canyon) / canyonWidth
                top += k * k * h * 0.45
            }
            top.coerceAtLeast(40.0)
        }
        fillColumns(tops)
        caves(3 + r.nextInt(4))
        ledges(2 + r.nextInt(3))
    }

    /** Low dunes, flat-topped mesas and a canyon that drops into the water. */
    fun dunes() {
        val list = waves(3, 1.5)
        val tops = DoubleArray(w) { x -> h * 0.6 - waveSum(x, list) * h * 0.14 + edgeDrop(x) }
        repeat(2 + r.nextInt(2)) { i ->
            val side = if (i % 2 == 0) 0.15 + r.nextDouble() * 0.2 else 0.62 + r.nextDouble() * 0.2
            val cx = (w * side).toInt()
            val half = 70 + r.nextInt(50)
            val rise = 110.0 + r.nextDouble() * 90
            val flat = tops[cx] - rise
            for (x in max(0, cx - half - 30) until min(w, cx + half + 30)) {
                val d = abs(x - cx) - half
                val top = if (d <= 0) flat else flat + d / 30.0 * rise
                tops[x] = min(tops[x], top)
            }
        }
        val canyon = w * (0.45 + r.nextDouble() * 0.1)
        val canyonWidth = 70 + r.nextDouble() * 40
        for (x in 0 until w) {
            if (abs(x - canyon) < canyonWidth) {
                val k = 1 - abs(x - canyon) / canyonWidth
                tops[x] += k * h * 0.5
            }
            tops[x] = tops[x].coerceAtLeast(60.0)
        }
        fillColumns(tops)
        caves(2 + r.nextInt(2), minDepth = 50.0)
    }

    /** A chain of islands with open sea between them. */
    fun islands() {
        val tops = DoubleArray(w) { h.toDouble() }
        val n = 4 + r.nextInt(2)
        val slot = w.toDouble() / n
        repeat(n) { i ->
            val cx = slot * (i + 0.5) + (r.nextDouble() - 0.5) * slot * 0.2
            val half = slot * (0.3 + r.nextDouble() * 0.12)
            val rise = 170 + r.nextDouble() * 170
            val phase = r.nextDouble() * 2 * PI
            for (x in max(0, (cx - half).toInt()) until min(w, (cx + half).toInt())) {
                val d = (x - cx) / half
                val k = 1 - d * d
                if (k <= 0) continue
                val top = t.waterY + 25 - rise * sqrt(k) * (0.88 + 0.12 * sin(x * 0.03 + phase))
                tops[x] = min(tops[x], top)
            }
        }
        fillColumns(tops)
        caves(2 + r.nextInt(2), minDepth = 45.0)
        ledges(1 + r.nextInt(2), top = 0.3, spread = 0.15)
    }

    /** Two castles with towers and halls, a moat and a thin bridge. */
    fun fortress() {
        val list = waves(2, 1.0)
        val center = w / 2.0
        val tops = DoubleArray(w) { x ->
            var top = h * 0.72 - waveSum(x, list) * 30 + edgeDrop(x, margin = 0.08)
            val d = abs(x - center)
            if (d < 110) top += (1 - d / 110) * h * 0.4
            top
        }
        fillColumns(tops)
        // The bridge over the moat.
        val bridgeY = (tops[(center - 150).toInt()] + tops[(center + 150).toInt()]) / 2 - 2
        rect((center - 150).toInt(), bridgeY.toInt(), (center + 150).toInt(), bridgeY.toInt() + 10, solid = true)
        castle((w * 0.24).toInt(), tops, doorOnRight = true)
        castle((w * 0.76).toInt(), tops, doorOnRight = false)
    }

    private fun castle(cx: Int, tops: DoubleArray, doorOnRight: Boolean) {
        val half = 105
        val ground = tops[cx].toInt()
        val roof = ground - 190
        val wall = 24
        // Flatten the ground under the castle.
        rect(cx - half - 20, ground, cx + half + 20, h, solid = true)
        rect(cx - half - 20, ground - 60, cx + half + 20, ground, solid = false)
        // Keep with a hollow hall.
        rect(cx - half, roof, cx + half, ground, solid = true)
        rect(cx - half + wall, roof + 28, cx + half - wall, ground, solid = false)
        // Doorway facing the enemy and a window on the far side.
        val doorX = if (doorOnRight) cx + half - wall else cx - half
        rect(doorX, ground - 44, doorX + wall, ground, solid = false)
        val windowX = if (doorOnRight) cx - half else cx + half - wall
        rect(windowX, roof + 70, windowX + wall, roof + 100, solid = false)
        // Towers on both corners, with battlements.
        for (side in intArrayOf(-1, 1)) {
            val tx = cx + side * (half - 25)
            rect(tx - 26, roof - 80, tx + 26, roof, solid = true)
            for (m in 0 until 3) rect(tx - 26 + m * 20, roof - 94, tx - 26 + m * 20 + 12, roof - 80, solid = true)
        }
        var mx = cx - half + 56
        while (mx < cx + half - 60) {
            rect(mx, roof - 12, mx + 14, roof, solid = true)
            mx += 28
        }
    }

    /** A cave system with a rock roof, stalactites and pillars. */
    fun cavern() {
        val roofWaves = waves(3, 2.0)
        val floorWaves = waves(4, 2.5)
        val ceiling = IntArray(w) { x -> (110 + waveSum(x, roofWaves) * 70).toInt().coerceIn(50, 230) }
        val floor = IntArray(w) { x -> (650 - waveSum(x, floorWaves) * 110 + edgeDrop(x, margin = 0.1)).toInt() }
        for (x in 0 until w) {
            for (y in 0 until ceiling[x]) t.set(x, y, true)
            for (y in floor[x].coerceAtLeast(0) until h) t.set(x, y, true)
        }
        // Stalactites hang from the roof, stalagmites grow from the floor.
        repeat(10 + r.nextInt(5)) {
            val cx = (w * (0.05 + r.nextDouble() * 0.9)).toInt()
            spike(cx, ceiling[cx], 40 + r.nextDouble() * 90, 9 + r.nextDouble() * 14, down = true)
        }
        repeat(5 + r.nextInt(4)) {
            val cx = (w * (0.15 + r.nextDouble() * 0.7)).toInt()
            if (floor[cx] < t.waterY - 20) spike(cx, floor[cx], 30 + r.nextDouble() * 50, 12 + r.nextDouble() * 10, down = false)
        }
        // Pillars from roof to floor, each with a tunnel through the bottom.
        repeat(2) { i ->
            val cx = (w * (0.33 + i * 0.34 + (r.nextDouble() - 0.5) * 0.08)).toInt()
            val half = 22 + r.nextInt(12)
            val bottom = floor[cx]
            rect(cx - half, 0, cx + half, bottom + 4, solid = true)
            ellipse(cx.toDouble(), bottom - 26.0, half + 14.0, 24.0, solid = false)
        }
        // Tunnels in the floor.
        repeat(2 + r.nextInt(2)) {
            val cx = w * (0.15 + r.nextDouble() * 0.7)
            val cy = floor[cx.toInt()] + 70 + r.nextDouble() * 80
            if (cy < t.waterY - 40) ellipse(cx, cy, 60 + r.nextDouble() * 70, 20 + r.nextDouble() * 20, solid = false)
        }
    }

    private fun spike(cx: Int, base: Int, length: Double, half: Double, down: Boolean) {
        for (i in 0 until length.toInt()) {
            val k = 1 - i / length
            val hw = (half * k).toInt()
            val y = if (down) base + i else base - i
            for (x in cx - hw..cx + hw) t.set(x, y, true)
        }
    }

    /** Floating islands; anything that falls off lands in the sea far below. */
    fun sky() {
        val n = 8
        val slot = w * 0.86 / n
        repeat(n) { i ->
            val cx = w * 0.07 + slot * (i + 0.5) + (r.nextDouble() - 0.5) * slot * 0.3
            val cy = h * (if (i % 2 == 0) 0.38 else 0.58) + (r.nextDouble() - 0.5) * h * 0.12
            val half = 75 + r.nextDouble() * 55
            val depth = 90 + r.nextDouble() * 80
            val phase = r.nextDouble() * 2 * PI
            for (x in (cx - half).toInt()..(cx + half).toInt()) {
                val d = (x - cx) / half
                if (abs(d) > 1) continue
                val top = cy - 14 * sqrt(1 - d * d)
                val bottom = cy + depth * (1 - abs(d)) * (0.75 + 0.25 * sin(x * 0.08 + phase))
                for (y in top.toInt()..bottom.toInt()) t.set(x, y, true)
            }
        }
        // A couple of small stepping stones between the islands.
        repeat(3) {
            val cx = w * (0.2 + r.nextDouble() * 0.6)
            val cy = h * (0.2 + r.nextDouble() * 0.1)
            ellipse(cx, cy, 30 + r.nextDouble() * 15, 9.0, solid = true)
        }
    }

    /** Sharp ridged mountains with ice shelves. */
    fun snow() {
        val list = List(4) { Triple(1.0 + r.nextDouble() * 2.0 * (it + 1), r.nextDouble() * 2 * PI, 0.5 / (it + 1)) }
        val tops = DoubleArray(w) { x ->
            val u = x.toDouble() / w
            var v = 0.0
            for ((freq, phase, weight) in list) v += (1 - abs(sin(u * freq * PI + phase))) * weight
            (h * 0.75 - v * h * 0.42 + edgeDrop(x)).coerceAtLeast(50.0)
        }
        fillColumns(tops)
        caves(2 + r.nextInt(2))
        ledges(2 + r.nextInt(2), top = 0.2, spread = 0.15)
    }

    /** One big volcano with a crater on top and lava tubes inside. */
    fun volcano() {
        val list = waves(3, 2.0)
        val c = w * (0.5 + (r.nextDouble() - 0.5) * 0.1)
        val sigma = 250 + r.nextDouble() * 50
        val peak = h * 0.48
        val tops = DoubleArray(w) { x ->
            val dx = (x - c) / sigma
            var top = h * 0.74 - waveSum(x, list) * h * 0.06 - peak * exp(-dx * dx) + edgeDrop(x)
            val d = abs(x - c)
            if (d < 70) top += (1 - (d / 70) * (d / 70)) * 75
            top
        }
        fillColumns(tops)
        // Lava tubes through the mountain.
        ellipse(c - 150, h * 0.55, 80.0, 20.0, solid = false)
        ellipse(c + 150, h * 0.62, 80.0, 20.0, solid = false)
        caves(2)
    }

    /** Dusty plains full of craters. */
    fun moon() {
        val list = waves(3, 2.0)
        val tops = DoubleArray(w) { x -> h * 0.6 - waveSum(x, list) * h * 0.1 + edgeDrop(x) }
        fillColumns(tops)
        repeat(6 + r.nextInt(4)) {
            val cx = w * (0.13 + r.nextDouble() * 0.74)
            val rad = 35 + r.nextDouble() * 55
            val ground = t.groundBelow(cx.toInt()) ?: return@repeat
            ellipse(cx, ground + rad * 0.5, rad, rad * 0.8, solid = false)
        }
        caves(1 + r.nextInt(2))
    }

    /** Round candy blobs with bubbles inside and floating lollipops. */
    fun candy() {
        val base = h * 0.76
        rect((w * 0.1).toInt(), base.toInt(), (w * 0.9).toInt(), h, solid = true)
        var x = w * 0.1
        while (x < w * 0.9) {
            val rad = 60 + r.nextDouble() * 70
            ellipse(x, base - rad * 0.3 - r.nextDouble() * 90, rad, rad, solid = true)
            x += 70 + r.nextDouble() * 70
        }
        repeat(5) {
            val cx = w * (0.15 + r.nextDouble() * 0.7)
            val ground = t.groundBelow(cx.toInt()) ?: return@repeat
            val cy = ground + 50 + r.nextDouble() * 100
            if (cy < t.waterY - 40) ellipse(cx, cy, 25 + r.nextDouble() * 25, 25 + r.nextDouble() * 15, solid = false)
        }
        repeat(3) {
            val cx = w * (0.2 + r.nextDouble() * 0.6)
            val cy = h * (0.22 + r.nextDouble() * 0.12)
            val rad = 26 + r.nextDouble() * 14
            ellipse(cx, cy, rad, rad, solid = true)
            rect(cx.toInt() - 3, cy.toInt(), cx.toInt() + 3, (cy + rad + 40).toInt(), solid = true)
        }
    }
}
