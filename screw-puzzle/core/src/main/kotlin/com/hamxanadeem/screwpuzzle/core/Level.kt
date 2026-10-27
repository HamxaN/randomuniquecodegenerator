package com.hamxanadeem.screwpuzzle.core

import kotlin.math.hypot

/**
 * Board coordinates: x from 0 to 1, y from 0 to [Level.BOARD_HEIGHT], y down.
 */
sealed interface PlateShape {
    fun contains(x: Double, y: Double, margin: Double = 0.0): Boolean

    data class Rect(val cx: Double, val cy: Double, val w: Double, val h: Double) : PlateShape {
        override fun contains(x: Double, y: Double, margin: Double): Boolean =
            x >= cx - w / 2 - margin && x <= cx + w / 2 + margin && y >= cy - h / 2 - margin && y <= cy + h / 2 + margin
    }

    data class Circle(val cx: Double, val cy: Double, val r: Double) : PlateShape {
        override fun contains(x: Double, y: Double, margin: Double): Boolean = hypot(x - cx, y - cy) <= r + margin
    }
}

/** A see-through plate. Higher [layer]s sit on top and cover the screws below. */
data class Plate(val id: Int, val layer: Int, val shape: PlateShape, val tint: Int)

/** A screw holding [plateId] to the board, with a coloured cap. */
data class Screw(val id: Int, val plateId: Int, val x: Double, val y: Double, val color: Int)

data class Level(
    val number: Int,
    val plates: List<Plate>,
    val screws: List<Screw>,
    /** The colours of the boxes, in the order they arrive. Each takes [Puzzle.BOX_SIZE] screws. */
    val boxes: List<Int>,
    val colors: Int,
    /** Screw ids in an order that clears the level without using the tray. */
    val solution: List<Int>,
) {
    companion object {
        const val BOARD_HEIGHT = 1.25
        const val SCREW_RADIUS = 0.036
    }
}
