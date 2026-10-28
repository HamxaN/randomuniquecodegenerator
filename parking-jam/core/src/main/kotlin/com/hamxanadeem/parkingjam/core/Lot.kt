package com.hamxanadeem.parkingjam.core

import kotlin.random.Random

enum class Dir(val dx: Int, val dy: Int) {
    UP(0, -1), DOWN(0, 1), LEFT(-1, 0), RIGHT(1, 0);

    val horizontal: Boolean get() = dx != 0
}

/**
 * A vehicle parked on the grid. ([x], [y]) is its rear-most cell; it covers [length]
 * cells in direction [dir], which is also the way it drives when tapped.
 */
data class Car(val id: Int, val x: Int, val y: Int, val length: Int, val dir: Dir, val color: Int) {
    fun cells(): List<Pair<Int, Int>> = List(length) { x + dir.dx * it to y + dir.dy * it }

    /** The cell just in front of the bonnet. */
    val front: Pair<Int, Int> get() = (x + dir.dx * (length - 1)) to (y + dir.dy * (length - 1))
}

sealed interface TapResult {
    /** The car drove out of the lot. [distance] is how many cells it crossed on the way. */
    data class Exited(val car: Car, val distance: Int) : TapResult
    /** Another car is in the way; the tapped car bumps into it. [gap] is how far it can roll first. */
    data class Bumped(val car: Car, val blocker: Car, val gap: Int) : TapResult
    data object Nothing : TapResult
}

/** A parking lot: tap cars to drive them out in the way they face; clear the lot to win. */
class Lot(val width: Int, val height: Int, cars: List<Car>) {

    private val parked = LinkedHashMap<Int, Car>().apply { cars.forEach { put(it.id, it) } }
    private val grid = Array(height) { IntArray(width) { -1 } }

    var taps = 0
        private set
    var bumps = 0
        private set

    init {
        for (c in cars) for ((cx, cy) in c.cells()) {
            require(cx in 0 until width && cy in 0 until height) { "car ${c.id} is outside the lot" }
            require(grid[cy][cx] == -1) { "cars ${grid[cy][cx]} and ${c.id} overlap" }
            grid[cy][cx] = c.id
        }
    }

    val cars: Collection<Car> get() = parked.values
    val cleared: Boolean get() = parked.isEmpty()
    val startCount = cars.size

    fun carAt(x: Int, y: Int): Car? =
        if (x in 0 until width && y in 0 until height) grid[y][x].takeIf { it >= 0 }?.let { parked[it] } else null

    /** The first car in [car]'s way, and how many free cells there are before it; null if the way is clear. */
    fun blocker(car: Car): Pair<Car, Int>? {
        var (fx, fy) = car.front
        var gap = 0
        while (true) {
            fx += car.dir.dx
            fy += car.dir.dy
            if (fx !in 0 until width || fy !in 0 until height) return null
            val other = carAt(fx, fy)
            if (other != null && other.id != car.id) return other to gap
            gap++
        }
    }

    fun canExit(car: Car): Boolean = blocker(car) == null

    fun tap(id: Int): TapResult {
        val car = parked[id] ?: return TapResult.Nothing
        taps++
        val block = blocker(car)
        if (block != null) {
            bumps++
            return TapResult.Bumped(car, block.first, block.second)
        }
        for ((cx, cy) in car.cells()) grid[cy][cx] = -1
        parked.remove(id)
        val (fx, fy) = car.front
        val distance = when (car.dir) {
            Dir.RIGHT -> width - 1 - fx
            Dir.LEFT -> fx
            Dir.DOWN -> height - 1 - fy
            Dir.UP -> fy
        }
        return TapResult.Exited(car, distance)
    }

    /** A car that can leave right now, for the hint button. */
    fun hint(): Car? = cars.firstOrNull { canExit(it) }

    /** Stars for a cleared lot: three with no bumps, two with a couple, otherwise one. */
    fun stars(): Int = when {
        bumps == 0 -> 3
        bumps <= 2 -> 2
        else -> 1
    }
}

/** Builds levels that always have a solution, getting bigger and fuller as you go. */
object LotGenerator {

    data class Shape(val width: Int, val height: Int, val cars: Int, val trucks: Double)

    fun shape(level: Int): Shape {
        val l = level.coerceAtLeast(1)
        val width = when {
            l < 8 -> 5
            l < 25 -> 6
            l < 60 -> 7
            else -> 8
        }
        val height = width + if (l < 8) 2 else 3
        val cells = width * height
        val cars = minOf((cells * 0.42).toInt() / 2, 6 + l / 2 + l / 8)
        return Shape(width, height, cars, trucks = minOf(0.3, 0.05 + l * 0.01))
    }

    /**
     * Places cars one by one so each has a clear way out past the cars already
     * there. Driving them out in reverse order of placement always works, so every
     * level is solvable. Each new car goes where it blocks the most cars already
     * placed, and the most tangled of several attempts is kept.
     */
    fun generate(level: Int, seed: Long = level * 7919L + 17): Lot {
        val s = shape(level)
        val random = Random(seed)
        var best: List<Car> = emptyList()
        var bestScore = -1
        repeat(ATTEMPTS) {
            val cars = place(s, random)
            val score = layers(s, cars) * 100 + blockedAtStart(s, cars)
            if (cars.size > best.size || (cars.size == best.size && score > bestScore)) {
                best = cars
                bestScore = score
            }
        }
        return Lot(s.width, s.height, best)
    }

    private fun place(s: Shape, random: Random): List<Car> {
        val cars = ArrayList<Car>()
        val taken = Array(s.height) { IntArray(s.width) { -1 } }
        var failures = 0
        while (cars.size < s.cars && failures < 60) {
            var pick: Car? = null
            var pickScore = -1
            repeat(CANDIDATES) {
                val dir = Dir.entries[random.nextInt(4)]
                val length = if (random.nextDouble() < s.trucks) 3 else 2
                val car = Car(cars.size, random.nextInt(s.width), random.nextInt(s.height), length, dir, COLORS[cars.size % COLORS.size])
                if (car.cells().any { (cx, cy) -> cx !in 0 until s.width || cy !in 0 until s.height || taken[cy][cx] >= 0 }) return@repeat
                if (pathCars(s, car, taken).isNotEmpty()) return@repeat
                // How many existing cars would now have this one in their way.
                val cells = car.cells().toSet()
                val blocks = cars.count { other -> pathCells(s, other).any { it in cells } }
                val score = blocks * 10 + random.nextInt(10)
                if (score > pickScore) {
                    pick = car
                    pickScore = score
                }
            }
            val car = pick
            if (car == null) {
                failures++
                continue
            }
            cars += car
            for ((cx, cy) in car.cells()) taken[cy][cx] = car.id
        }
        return cars
    }

    /** Cells between [car]'s bonnet and the edge of the lot. */
    private fun pathCells(s: Shape, car: Car): List<Pair<Int, Int>> {
        val out = ArrayList<Pair<Int, Int>>()
        var (fx, fy) = car.front
        while (true) {
            fx += car.dir.dx
            fy += car.dir.dy
            if (fx !in 0 until s.width || fy !in 0 until s.height) return out
            out += fx to fy
        }
    }

    private fun pathCars(s: Shape, car: Car, taken: Array<IntArray>): List<Int> =
        pathCells(s, car).mapNotNull { (x, y) -> taken[y][x].takeIf { it >= 0 } }

    /** How many rounds of "drive out everything that can go" it takes to clear the lot. */
    fun layers(s: Shape, cars: List<Car>): Int {
        val lot = Lot(s.width, s.height, cars)
        var rounds = 0
        while (!lot.cleared) {
            val free = lot.cars.filter { lot.canExit(it) }
            if (free.isEmpty()) return -1
            free.forEach { lot.tap(it.id) }
            rounds++
        }
        return rounds
    }

    private fun blockedAtStart(s: Shape, cars: List<Car>): Int {
        val lot = Lot(s.width, s.height, cars)
        return lot.cars.count { !lot.canExit(it) }
    }

    private const val ATTEMPTS = 12
    private const val CANDIDATES = 40

    /** Car body colours (ARGB). */
    val COLORS = intArrayOf(
        0xFFE53935.toInt(), 0xFF1E88E5.toInt(), 0xFFFDD835.toInt(), 0xFF43A047.toInt(), 0xFF8E24AA.toInt(),
        0xFFFB8C00.toInt(), 0xFF00ACC1.toInt(), 0xFFEC407A.toInt(), 0xFF6D4C41.toInt(), 0xFFF5F5F5.toInt(),
    )
}
