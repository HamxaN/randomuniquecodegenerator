package com.hamxanadeem.screwpuzzle.core

/** Where a screw is. */
sealed interface Spot {
    data object Board : Spot
    data class InBox(val boxId: Int, val hole: Int) : Spot
    data class InTray(val index: Int) : Spot
}

/** A box on screen. [id] is its position in the level's box queue. */
data class Box(val id: Int, val color: Int, val slot: Int, var filled: Int = 0)

sealed interface PuzzleEvent {
    data class ScrewMoved(val screwId: Int, val from: Spot, val to: Spot) : PuzzleEvent
    data class PlateFreed(val plateId: Int) : PuzzleEvent
    data class BoxCompleted(val boxId: Int) : PuzzleEvent
    data class BoxArrived(val box: Box) : PuzzleEvent
    data object Won : PuzzleEvent
    data object Stuck : PuzzleEvent
}

sealed interface TapResult {
    data class Moved(val events: List<PuzzleEvent>) : TapResult
    /** Covered by these plates. */
    data class Blocked(val by: List<Int>) : TapResult
    data object NoRoom : TapResult
    data object Ignored : TapResult
}

/**
 * The rules. Tap a screw that no plate covers: it goes into an on-screen box of its
 * colour if one has room, otherwise into the holding tray. A plate with no screws
 * left falls away. A full box leaves and the next one arrives, taking matching
 * screws from the tray. Clear every screw to win; you're stuck when the tray is full
 * and no free screw fits a box.
 */
class Puzzle(val level: Level) {

    private val platesById = level.plates.associateBy { it.id }
    private val remainingPlates = level.plates.map { it.id }.toMutableSet()
    private val spots = HashMap<Int, Spot>().apply { level.screws.forEach { put(it.id, Spot.Board) } }
    private val screwsLeftOnPlate = HashMap<Int, Int>().apply {
        level.screws.forEach { merge(it.plateId, 1, Int::plus) }
    }

    private val active = arrayOfNulls<Box>(ACTIVE_BOXES)
    private var nextBox = 0

    var trayCapacity = TRAY_SIZE
        private set
    private val tray = arrayOfNulls<Int>(TRAY_SIZE + 1)
    var extraSlotUsed = false
        private set
    var moves = 0
        private set

    init {
        for (slot in 0 until ACTIVE_BOXES) bringNextBox(slot, ArrayList())
    }

    val plates: List<Plate> get() = level.plates.filter { it.id in remainingPlates }
    fun isPlatePresent(plateId: Int) = plateId in remainingPlates
    fun spotOf(screwId: Int): Spot = spots.getValue(screwId)
    fun activeBox(slot: Int): Box? = active[slot]
    fun trayScrew(index: Int): Int? = tray[index]

    val boxesLeft: Int get() = level.boxes.size - nextBox + active.count { it != null }
    val isWon: Boolean get() = spots.values.all { it is Spot.InBox } && tray.all { it == null }

    fun blockers(screw: Screw): List<Int> {
        val layer = platesById.getValue(screw.plateId).layer
        return remainingPlates.map { platesById.getValue(it) }
            .filter { it.layer > layer && it.shape.contains(screw.x, screw.y, Level.SCREW_RADIUS) }
            .map { it.id }
    }

    fun isFree(screw: Screw): Boolean = spots[screw.id] == Spot.Board && blockers(screw).isEmpty()

    /** No free screw can be placed anywhere. */
    val isStuck: Boolean
        get() {
            if (isWon) return false
            val trayFull = (0 until trayCapacity).all { tray[it] != null }
            if (!trayFull) return false
            return level.screws.none { s -> isFree(s) && boxFor(s.color) != null }
        }

    fun tap(screwId: Int): TapResult {
        val screw = level.screws.getOrNull(screwId) ?: return TapResult.Ignored
        if (spots[screw.id] != Spot.Board) return TapResult.Ignored
        val blockers = blockers(screw)
        if (blockers.isNotEmpty()) return TapResult.Blocked(blockers)

        val events = ArrayList<PuzzleEvent>()
        val box = boxFor(screw.color)
        val to: Spot = if (box != null) {
            Spot.InBox(box.id, box.filled++)
        } else {
            val index = (0 until trayCapacity).firstOrNull { tray[it] == null } ?: return TapResult.NoRoom
            tray[index] = screw.id
            Spot.InTray(index)
        }
        spots[screw.id] = to
        moves++
        events += PuzzleEvent.ScrewMoved(screw.id, Spot.Board, to)

        val left = screwsLeftOnPlate.getValue(screw.plateId) - 1
        screwsLeftOnPlate[screw.plateId] = left
        if (left == 0) {
            remainingPlates -= screw.plateId
            events += PuzzleEvent.PlateFreed(screw.plateId)
        }
        settleBoxes(events)
        if (isWon) events += PuzzleEvent.Won else if (isStuck) events += PuzzleEvent.Stuck
        return TapResult.Moved(events)
    }

    private fun boxFor(color: Int): Box? = active.firstOrNull { it != null && it.color == color && it.filled < BOX_SIZE }

    /** Sends full boxes away, brings new ones, and fills them from the tray. */
    private fun settleBoxes(events: MutableList<PuzzleEvent>) {
        var changed = true
        while (changed) {
            changed = false
            for (slot in 0 until ACTIVE_BOXES) {
                val box = active[slot] ?: continue
                if (box.filled == BOX_SIZE) {
                    events += PuzzleEvent.BoxCompleted(box.id)
                    active[slot] = null
                    bringNextBox(slot, events)
                    changed = true
                }
            }
        }
    }

    private fun bringNextBox(slot: Int, events: MutableList<PuzzleEvent>) {
        if (nextBox >= level.boxes.size) return
        val box = Box(nextBox, level.boxes[nextBox], slot)
        nextBox++
        active[slot] = box
        events += PuzzleEvent.BoxArrived(box)
        // Matching screws waiting in the tray jump in.
        for (i in tray.indices) {
            val screwId = tray[i] ?: continue
            if (box.filled < BOX_SIZE && level.screws[screwId].color == box.color) {
                tray[i] = null
                val to = Spot.InBox(box.id, box.filled++)
                spots[screwId] = to
                events += PuzzleEvent.ScrewMoved(screwId, Spot.InTray(i), to)
            }
        }
    }

    /** Rewarded ad: one more tray slot, once per level. */
    fun addTraySlot(): Boolean {
        if (extraSlotUsed) return false
        extraSlotUsed = true
        trayCapacity++
        return true
    }

    companion object {
        const val BOX_SIZE = 3
        const val ACTIVE_BOXES = 2
        const val TRAY_SIZE = 5
    }
}
