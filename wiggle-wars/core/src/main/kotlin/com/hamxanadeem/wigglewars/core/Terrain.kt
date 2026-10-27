package com.hamxanadeem.wigglewars.core

import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/** A rectangle of terrain cells that changed, so the renderer only redraws that part. */
data class Area(val left: Int, val top: Int, val right: Int, val bottom: Int)

/**
 * Destructible land: one byte per pixel, solid or air. Coordinates are pixels with
 * y growing downwards. Below [waterY] is the sea.
 */
class Terrain(val width: Int, val height: Int) {

    private val solid = ByteArray(width * height)

    val waterY: Int get() = height - WATER_DEPTH

    fun isSolid(x: Int, y: Int): Boolean =
        x in 0 until width && y in 0 until height && solid[y * width + x] != 0.toByte()

    fun isSolid(x: Double, y: Double): Boolean = isSolid(x.toInt(), y.toInt())

    fun set(x: Int, y: Int, value: Boolean) {
        if (x in 0 until width && y in 0 until height) solid[y * width + x] = if (value) 1 else 0
    }

    /** Blasts a round hole. Returns the area that changed, or null if nothing was solid. */
    fun carve(cx: Double, cy: Double, radius: Double): Area? {
        val left = max(0, (cx - radius).toInt())
        val right = min(width - 1, (cx + radius).toInt() + 1)
        val top = max(0, (cy - radius).toInt())
        val bottom = min(height - 1, (cy + radius).toInt() + 1)
        if (left > right || top > bottom) return null
        val r2 = radius * radius
        var changed = false
        for (y in top..bottom) {
            val dy = y + 0.5 - cy
            for (x in left..right) {
                val dx = x + 0.5 - cx
                if (dx * dx + dy * dy <= r2) {
                    val i = y * width + x
                    if (solid[i] != 0.toByte()) {
                        solid[i] = 0
                        changed = true
                    }
                }
            }
        }
        return if (changed) Area(left, top, right, bottom) else null
    }

    /** The first solid y going down from [fromY] at column [x], or null if there is none above the water. */
    fun groundBelow(x: Int, fromY: Int = 0): Int? {
        for (y in max(0, fromY) until waterY) if (isSolid(x, y)) return y
        return null
    }

    fun solidCount(): Int = solid.count { it != 0.toByte() }

    companion object {
        const val WATER_DEPTH = 70

        /**
         * Rolling islands with caves and tunnels. The ends drop into the sea so worms
         * can be knocked off the map.
         */
        fun generate(seed: Long, width: Int = 2000, height: Int = 1000): Terrain {
            val t = Terrain(width, height)
            val r = Random(seed)
            val waves = List(5) { Triple(0.5 + r.nextDouble() * 3.0 * (it + 1), r.nextDouble() * 2 * PI, 0.4 / (it + 1)) }
            val base = height * 0.5
            val amplitude = height * 0.22
            // Optional canyon splitting the land into two islands.
            val canyon = if (r.nextBoolean()) width * (0.4 + r.nextDouble() * 0.2) else -1.0
            val canyonWidth = 50 + r.nextDouble() * 60
            for (x in 0 until width) {
                val u = x.toDouble() / width
                var h = 0.0
                for ((freq, phase, weight) in waves) h += sin(u * freq * 2 * PI + phase) * weight
                // Fall away into the sea at both ends.
                val edge = min(1.0, min(u, 1 - u) / 0.12)
                var top = base - h * amplitude
                top += (1 - edge) * height * 0.6
                if (canyon > 0 && kotlin.math.abs(x - canyon) < canyonWidth) {
                    val k = 1 - kotlin.math.abs(x - canyon) / canyonWidth
                    top += k * k * height * 0.45
                }
                val start = top.toInt().coerceIn(40, height)
                for (y in start until height) t.set(x, y, true)
            }
            // Caves and tunnels.
            repeat(3 + r.nextInt(4)) {
                val cx = width * (0.15 + r.nextDouble() * 0.7)
                val ground = t.groundBelow(cx.toInt()) ?: return@repeat
                val cy = ground + 60 + r.nextDouble() * 140
                if (cy > t.waterY - 40) return@repeat
                val rx = 40 + r.nextDouble() * 90
                val ry = 22 + r.nextDouble() * 30
                for (y in (cy - ry).toInt()..(cy + ry).toInt()) for (x in (cx - rx).toInt()..(cx + rx).toInt()) {
                    val dx = (x - cx) / rx
                    val dy = (y - cy) / ry
                    if (dx * dx + dy * dy <= 1) t.set(x, y, false)
                }
            }
            // A few floating ledges in the sky.
            repeat(2 + r.nextInt(3)) {
                val cx = width * (0.15 + r.nextDouble() * 0.7)
                val cy = height * (0.15 + r.nextDouble() * 0.2)
                val rx = 50 + r.nextDouble() * 70
                val ry = 10 + r.nextDouble() * 10
                for (y in (cy - ry).toInt()..(cy + ry * 1.8).toInt()) for (x in (cx - rx).toInt()..(cx + rx).toInt()) {
                    val dx = (x - cx) / rx
                    val dy = if (y < cy) (y - cy) / ry else (y - cy) / (ry * 1.8)
                    if (dx * dx + dy * dy <= 1) t.set(x, y, true)
                }
            }
            return t
        }
    }
}
