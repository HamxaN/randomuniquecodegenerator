package com.hamxanadeem.wigglewars.core

import kotlin.math.max
import kotlin.math.min

/** A rectangle of terrain cells that changed, so the renderer only redraws that part. */
data class Area(val left: Int, val top: Int, val right: Int, val bottom: Int)

/**
 * Destructible land: one byte per pixel, solid or air. Coordinates are pixels with
 * y growing downwards. Below [waterY] is the sea.
 */
class Terrain(val width: Int, val height: Int) {

    private val solid = ByteArray(width * height)

    /** The sea level. It rises during sudden death. */
    var waterY: Int = height - WATER_DEPTH
        internal set

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

    /** Fills a rectangle with land (for girders). Returns the area that changed. */
    fun fillRect(left: Int, top: Int, right: Int, bottom: Int): Area? {
        val l = max(0, left)
        val t = max(0, top)
        val r = min(width - 1, right)
        val b = min(height - 1, bottom)
        if (l > r || t > b) return null
        for (y in t..b) for (x in l..r) solid[y * width + x] = 1
        return Area(l, t, r, b)
    }

    /**
     * Every place in column [x] where land has open air above it, from the top down.
     * Used to spawn worms on any level: hilltops, cave floors, castle halls.
     */
    fun surfaces(x: Int, clearance: Int = 20): List<Int> {
        val out = ArrayList<Int>()
        var air = if (isSolid(x, 0)) 0 else clearance
        for (y in 0 until waterY) {
            if (isSolid(x, y)) {
                if (air >= clearance) out += y
                air = 0
            } else {
                air++
            }
        }
        return out
    }

    fun solidCount(): Int = solid.count { it != 0.toByte() }

    companion object {
        const val WATER_DEPTH = 70

        /** Builds the land for [arena]. The same seed and arena always give the same map. */
        fun generate(seed: Long, arena: Arena = Arena.HILLS, width: Int = 2000, height: Int = 1000): Terrain =
            arena.generate(seed, width, height)
    }
}
