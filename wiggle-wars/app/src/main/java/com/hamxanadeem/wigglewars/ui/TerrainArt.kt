package com.hamxanadeem.wigglewars.ui

import android.graphics.Bitmap
import androidx.core.graphics.createBitmap
import com.hamxanadeem.wigglewars.core.Area
import com.hamxanadeem.wigglewars.core.Terrain
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin

/**
 * Paints the terrain into a bitmap once (grass or sand on top, layered soil, stones)
 * and then only updates the pixels around each explosion, with a scorched rim.
 */
class TerrainArt(private val terrain: Terrain, private val theme: MapTheme) {

    val bitmap: Bitmap = createBitmap(terrain.width, terrain.height)
    private var buffer = IntArray(0)

    init {
        val w = terrain.width
        val h = terrain.height
        val pixels = IntArray(w * h)
        for (x in 0 until w) {
            var depth = -1
            for (y in 0 until h) {
                if (!terrain.isSolid(x, y)) {
                    depth = -1
                    continue
                }
                depth = if (depth < 0) 0 else depth + 1
                pixels[y * w + x] = colorAt(x, y, depth)
            }
        }
        bitmap.setPixels(pixels, 0, w, 0, 0, w, h)
    }

    private fun colorAt(x: Int, y: Int, depth: Int): Int {
        if (depth < 3) return theme.surface
        if (depth < 8) return mix(theme.surface, theme.surfaceDark, (depth - 3) / 5f)
        if (depth < 11) return mix(theme.surfaceDark, theme.soil, (depth - 8) / 3f)
        // Stones scattered through the soil.
        if (hash(x / 7, y / 7) % 100 < 3 && hash(x / 3, y / 3) % 3 != 0) return shade(theme.stone, 0.85f + (hash(x, y) % 20) / 100f)
        val noise = (hash(x / 2, y / 2) % 1000) / 1000f
        val bands = 0.5f + 0.5f * sin(y * 0.045f + sin(x * 0.01f) * 2f)
        val base = mix(theme.soil, theme.soilDark, bands * 0.35f + noise * 0.25f)
        return shade(base, 1f - min(0.35f, depth / 700f))
    }

    /** Updates the bitmap after an explosion at ([cx], [cy]). */
    fun blast(area: Area, cx: Double, cy: Double, radius: Double) {
        val pad = 5
        val left = (area.left - pad).coerceAtLeast(0)
        val top = (area.top - pad).coerceAtLeast(0)
        val right = (area.right + pad).coerceAtMost(terrain.width - 1)
        val bottom = (area.bottom + pad).coerceAtMost(terrain.height - 1)
        val w = right - left + 1
        val h = bottom - top + 1
        if (buffer.size < w * h) buffer = IntArray(w * h)
        bitmap.getPixels(buffer, 0, w, left, top, w, h)
        for (y in 0 until h) for (x in 0 until w) {
            val wx = left + x
            val wy = top + y
            val i = y * w + x
            if (!terrain.isSolid(wx, wy)) {
                buffer[i] = 0
            } else {
                val d = hypot(wx + 0.5 - cx, wy + 0.5 - cy)
                if (d < radius + 4) buffer[i] = shade(buffer[i], 0.55f)
            }
        }
        bitmap.setPixels(buffer, 0, w, left, top, w, h)
    }

    companion object {
        fun hash(x: Int, y: Int): Int {
            var h = x * 374761393 + y * 668265263
            h = (h xor (h ushr 13)) * 1274126177
            return (h xor (h ushr 16)) and 0x7FFFFFFF
        }

        fun mix(a: Int, b: Int, t: Float): Int {
            val k = t.coerceIn(0f, 1f)
            fun ch(s: Int) = ((a shr s and 0xFF) + ((b shr s and 0xFF) - (a shr s and 0xFF)) * k).toInt()
            return 0xFF000000.toInt() or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
        }

        fun shade(c: Int, f: Float): Int {
            fun ch(s: Int) = ((c shr s and 0xFF) * f).toInt().coerceIn(0, 255)
            return (c and 0xFF000000.toInt()) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
        }
    }
}
