package com.hamxanadeem.screwpuzzle.ui

/** Screw and box colours, and the tints of the acrylic plates. */
object Palette {
    val screw = intArrayOf(
        0xFFE53935.toInt(), // red
        0xFF1E88E5.toInt(), // blue
        0xFF43A047.toInt(), // green
        0xFFFDD835.toInt(), // yellow
        0xFF8E24AA.toInt(), // purple
        0xFFFB8C00.toInt(), // orange
        0xFF00ACC1.toInt(), // teal
    )
    val plate = intArrayOf(
        0xFF80DEEA.toInt(),
        0xFFF48FB1.toInt(),
        0xFFFFE082.toInt(),
        0xFFA5D6A7.toInt(),
        0xFFB39DDB.toInt(),
        0xFFFFAB91.toInt(),
    )

    fun darker(color: Int, factor: Float = 0.7f): Int {
        val r = ((color shr 16 and 0xFF) * factor).toInt()
        val g = ((color shr 8 and 0xFF) * factor).toInt()
        val b = ((color and 0xFF) * factor).toInt()
        return (color and 0xFF000000.toInt()) or (r shl 16) or (g shl 8) or b
    }

    fun withAlpha(color: Int, alpha: Int) = (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)
}
