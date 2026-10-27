package com.hamxanadeem.screwpuzzle.core

import kotlin.math.hypot
import kotlin.math.min
import kotlin.random.Random

/**
 * Builds levels that are always solvable. It first places plates and screws, then
 * finds a valid order to remove every screw (top plates first), and only then gives
 * the screws their colours: each run of six screws in that order shares the colours
 * of two boxes that are on screen together. Following that order clears the level
 * without ever using the holding tray, so the tray is pure slack for mistakes.
 */
object LevelGenerator {

    const val MAX_COLORS = 7

    fun generate(number: Int): Level {
        require(number >= 1) { "Levels start at 1" }
        val random = Random(number * 104729L + 17)
        val plateCount = min(3 + number / 2, 14)
        val colorCount = min(4 + number / 5, MAX_COLORS)

        // Retry until the layout has a multiple of 3 screws.
        while (true) {
            val (plates, positions) = layout(random, plateCount)
            if (positions.size < 3) continue
            val trimmed = trimToMultipleOfThree(positions, random) ?: continue
            if (plates.any { p -> trimmed.none { it.first == p.id } }) continue
            val order = removalOrder(plates, trimmed, random)
            val colors = colorSequence(trimmed.size / Puzzle.BOX_SIZE, colorCount, random)
            val screwColor = HashMap<Int, Int>()
            // Blocks of six screws in removal order use boxes 2j and 2j+1.
            var box = 0
            var i = 0
            while (i < order.size) {
                val block = order.subList(i, min(i + 6, order.size))
                val blockColors = if (block.size == 6) {
                    (List(3) { colors[box] } + List(3) { colors[box + 1] }).shuffled(random)
                } else {
                    List(block.size) { colors[box] }
                }
                block.forEachIndexed { k, index -> screwColor[index] = blockColors[k] }
                box += block.size / Puzzle.BOX_SIZE
                i += 6
            }
            val screws = trimmed.mapIndexed { index, (plateId, xy) ->
                Screw(index, plateId, xy.first, xy.second, screwColor.getValue(index))
            }
            return Level(number, plates, screws, colors, colorCount, order)
        }
    }

    private fun layout(random: Random, plateCount: Int): Pair<List<Plate>, List<Pair<Int, Pair<Double, Double>>>> {
        val plates = ArrayList<Plate>()
        val screws = ArrayList<Pair<Int, Pair<Double, Double>>>()
        val minGap = Level.SCREW_RADIUS * 2.6
        for (id in 0 until plateCount) {
            val shape: PlateShape = if (random.nextFloat() < 0.3f) {
                val r = 0.12 + random.nextDouble() * 0.1
                PlateShape.Circle(r + 0.06 + random.nextDouble() * (0.88 - 2 * r), r + 0.1 + random.nextDouble() * (Level.BOARD_HEIGHT - 0.2 - 2 * r), r)
            } else {
                val horizontal = random.nextBoolean()
                val long = 0.35 + random.nextDouble() * 0.4
                val short = 0.13 + random.nextDouble() * 0.12
                val w = if (horizontal) long else short
                val h = if (horizontal) short else long
                PlateShape.Rect(w / 2 + 0.05 + random.nextDouble() * (0.9 - w), h / 2 + 0.08 + random.nextDouble() * (Level.BOARD_HEIGHT - 0.16 - h), w, h)
            }
            val plate = Plate(id, id, shape, random.nextInt(6))
            val wanted = 1 + random.nextInt(3)
            var placed = 0
            var attempts = 0
            while (placed < wanted && attempts < 60) {
                attempts++
                val (x, y) = pointInside(shape, random)
                if (screws.any { hypot(it.second.first - x, it.second.second - y) < minGap }) continue
                screws += id to (x to y)
                placed++
            }
            if (placed > 0) plates += plate
        }
        return plates to screws
    }

    private fun pointInside(shape: PlateShape, random: Random): Pair<Double, Double> {
        val inset = Level.SCREW_RADIUS * 1.5
        return when (shape) {
            is PlateShape.Rect -> Pair(
                shape.cx - shape.w / 2 + inset + random.nextDouble() * (shape.w - 2 * inset),
                shape.cy - shape.h / 2 + inset + random.nextDouble() * (shape.h - 2 * inset),
            )
            is PlateShape.Circle -> {
                val angle = random.nextDouble() * 2 * Math.PI
                val d = random.nextDouble() * (shape.r - inset)
                Pair(shape.cx + kotlin.math.cos(angle) * d, shape.cy + kotlin.math.sin(angle) * d)
            }
        }
    }

    /** Drops screws (never a plate's last one) until the count is a multiple of 3. */
    private fun trimToMultipleOfThree(
        screws: List<Pair<Int, Pair<Double, Double>>>,
        random: Random,
    ): List<Pair<Int, Pair<Double, Double>>>? {
        val result = screws.toMutableList()
        while (result.size % 3 != 0) {
            val removable = result.indices.filter { i -> result.count { it.first == result[i].first } > 1 }
            if (removable.isEmpty()) return null
            result.removeAt(removable[random.nextInt(removable.size)])
        }
        return result
    }

    /** A random valid order: always remove some screw that no remaining plate covers. */
    fun removalOrder(plates: List<Plate>, screws: List<Pair<Int, Pair<Double, Double>>>, random: Random): List<Int> {
        val remainingPlates = plates.associateBy { it.id }.toMutableMap()
        val remainingScrews = screws.indices.toMutableSet()
        val order = ArrayList<Int>()
        while (remainingScrews.isNotEmpty()) {
            val free = remainingScrews.filter { i ->
                val (plateId, xy) = screws[i]
                val layer = remainingPlates.getValue(plateId).layer
                remainingPlates.values.none { it.layer > layer && it.shape.contains(xy.first, xy.second, Level.SCREW_RADIUS) }
            }
            val pick = free[random.nextInt(free.size)]
            order += pick
            remainingScrews -= pick
            val plateId = screws[pick].first
            if (remainingScrews.none { screws[it].first == plateId }) remainingPlates -= plateId
        }
        return order
    }

    /** Box colours where any four boxes in a row are all different. */
    private fun colorSequence(boxes: Int, colorCount: Int, random: Random): List<Int> {
        val result = ArrayList<Int>()
        repeat(boxes) {
            val recent = result.takeLast(3).toSet()
            val options = (0 until colorCount).filter { it !in recent }
            result += options[random.nextInt(options.size)]
        }
        return result
    }
}
