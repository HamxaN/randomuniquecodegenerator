package com.hamxanadeem.rewind.core

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.sign

/** A point in cell units: (0,0) is the top-left corner of the map, cells are 1 wide. */
data class Pt(val x: Double, val y: Double) {
    fun dist(o: Pt) = hypot(x - o.x, y - o.y)
}

/** A cell on the grid. */
data class Cell(val c: Int, val r: Int) {
    val center: Pt get() = Pt(c + 0.5, r + 0.5)
}

/**
 * One map: the road enemies walk (axis-aligned turns through cell centres, starting
 * and ending just off the map), the waves, and the starting gold and lives.
 */
class Level(
    val index: Int,
    val name: String,
    turns: List<Cell>,
    val startGold: Int,
    val lives: Int = 20,
    val waveCount: Int,
) {
    val points: List<Pt> = turns.map { it.center }
    private val cumulative: DoubleArray
    val length: Double

    /** Cells the road covers; you can't build on these. */
    val road: Set<Cell>

    init {
        require(turns.size >= 2)
        val cum = DoubleArray(points.size)
        for (i in 1 until points.size) cum[i] = cum[i - 1] + points[i].dist(points[i - 1])
        cumulative = cum
        length = cum.last()
        val cells = mutableSetOf<Cell>()
        for (i in 1 until turns.size) {
            val a = turns[i - 1]
            val b = turns[i]
            require(a.c == b.c || a.r == b.r) { "Road segments must be straight ($a → $b)" }
            val steps = max(abs(b.c - a.c), abs(b.r - a.r))
            val dc = sign((b.c - a.c).toDouble()).toInt()
            val dr = sign((b.r - a.r).toDouble()).toInt()
            for (k in 0..steps) {
                val cell = Cell(a.c + dc * k, a.r + dr * k)
                if (onMap(cell)) cells += cell
            }
        }
        road = cells
    }

    /** Where an enemy is after walking [d] cells along the road. */
    fun at(d: Double): Pt {
        if (d <= 0) return points.first()
        if (d >= length) return points.last()
        var i = 1
        while (cumulative[i] < d) i++
        val a = points[i - 1]
        val b = points[i]
        val k = (d - cumulative[i - 1]) / (cumulative[i] - cumulative[i - 1])
        return Pt(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k)
    }

    fun buildable(cell: Cell): Boolean = onMap(cell) && cell !in road

    /** The waves, built from the level's index so every player gets the same ones. */
    val waves: List<Wave> by lazy { Waves.forLevel(this) }

    companion object {
        const val COLS = 16
        const val ROWS = 9

        fun onMap(cell: Cell) = cell.c in 0 until COLS && cell.r in 0 until ROWS

        private fun l(i: Int, name: String, gold: Int, waves: Int, vararg t: Pair<Int, Int>) =
            Level(i, name, t.map { Cell(it.first, it.second) }, gold, waveCount = waves)

        val ALL: List<Level> = listOf(
            l(0, "Meadow", 260, 10, -1 to 2, 5 to 2, 5 to 6, 11 to 6, 11 to 2, 16 to 2),
            l(1, "Canyon", 280, 11, -1 to 1, 3 to 1, 3 to 7, 8 to 7, 8 to 1, 12 to 1, 12 to 7, 16 to 7),
            l(2, "Spiral", 300, 12, -1 to 4, 2 to 4, 2 to 1, 13 to 1, 13 to 7, 5 to 7, 5 to 4, 10 to 4, 10 to 9),
            l(3, "Crossing", 320, 13, 7 to -1, 7 to 3, 2 to 3, 2 to 6, 13 to 6, 13 to 2, 16 to 2),
            l(4, "Switchback", 340, 14, -1 to 1, 14 to 1, 14 to 3, 1 to 3, 1 to 5, 14 to 5, 14 to 7, -1 to 7),
            l(5, "Twin Rivers", 360, 15, -1 to 6, 4 to 6, 4 to 2, 9 to 2, 9 to 6, 13 to 6, 13 to -1),
            l(6, "Fortress", 380, 16, 8 to -1, 8 to 2, 3 to 2, 3 to 6, 12 to 6, 12 to 4, 6 to 4, 6 to 9),
            l(7, "The Gauntlet", 420, 17, -1 to 8, 2 to 8, 2 to 0, 5 to 0, 5 to 8, 8 to 8, 8 to 0, 11 to 0, 11 to 8, 14 to 8, 14 to -1),
        )
    }
}
