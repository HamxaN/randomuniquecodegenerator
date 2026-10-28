package com.hamxanadeem.tidyroom.core

import kotlin.math.hypot
import kotlin.random.Random

/** Things that belong somewhere. */
enum class ItemType {
    BOOK, MUG, PLANT, SHOE, PILLOW, TEDDY, LAMP, CLOCK, PLATE, BOTTLE, TOWEL, DUCK, FRAME, VASE, GAMEPAD, SOCK,
}

/** The kinds of room, each with its own furniture and places for things. */
enum class RoomKind(val displayName: String) {
    BEDROOM("Bedroom"), KITCHEN("Kitchen"), BATHROOM("Bathroom"), LIVING("Living Room"), PLAYROOM("Playroom"),
}

/**
 * A place where an item belongs, in room coordinates: x from 0 (left) to 1 (right),
 * y from 0 (ceiling) to 1 (floor). [size] is the item's width as a fraction of the room's.
 */
data class Slot(val id: Int, val type: ItemType, val x: Float, val y: Float, val size: Float)

/** An item lying around, waiting to be put away. */
class Item(val id: Int, val type: ItemType, var x: Float, var y: Float, val size: Float, val tilt: Float) {
    /** The slot it's been put in, or -1. */
    var slot = -1
    val placed: Boolean get() = slot >= 0
}

sealed interface DropResult {
    data class Placed(val item: Item, val slot: Slot) : DropResult
    /** Dropped somewhere that isn't its place: it stays where it was dropped (on the floor area). */
    data class Missed(val item: Item, val wrongSlot: Slot?) : DropResult
}

/** One messy room. Drag every item to a matching outline to tidy it. */
class Room(val kind: RoomKind, val slots: List<Slot>, val items: List<Item>) {

    var moves = 0
        private set
    var mistakes = 0
        private set

    val tidy: Boolean get() = items.all { it.placed }
    val placedCount: Int get() = items.count { it.placed }

    fun freeSlotsFor(type: ItemType): List<Slot> = slots.filter { s -> s.type == type && items.none { it.slot == s.id } }

    /**
     * Drops [itemId] at ([x], [y]). It snaps into the nearest free slot of its type
     * within reach; otherwise it lands where it was dropped.
     */
    fun drop(itemId: Int, x: Float, y: Float): DropResult {
        val item = items.first { it.id == itemId }
        moves++
        val reach = SNAP_REACH
        val target = freeSlotsFor(item.type).minByOrNull { hypot(it.x - x, it.y - y) }
        if (target != null && hypot(target.x - x, target.y - y) <= reach + target.size * 0.5f) {
            item.slot = target.id
            item.x = target.x
            item.y = target.y
            return DropResult.Placed(item, target)
        }
        // A free slot of another type nearby means the player guessed wrong.
        val wrong = slots.filter { s -> items.none { it.slot == s.id } }.minByOrNull { hypot(it.x - x, it.y - y) }
            ?.takeIf { hypot(it.x - x, it.y - y) <= reach + it.size * 0.5f }
        if (wrong != null) mistakes++
        item.x = x.coerceIn(0.06f, 0.94f)
        item.y = y.coerceIn(0.08f, 0.96f)
        return DropResult.Missed(item, wrong)
    }

    /** An item still lying around and a free place for it, for the hint button. */
    fun hint(): Pair<Item, Slot>? {
        for (item in items) {
            if (item.placed) continue
            val slot = freeSlotsFor(item.type).firstOrNull() ?: continue
            return item to slot
        }
        return null
    }

    /** Three stars for a tidy room with no wrong guesses, two with a couple, otherwise one. */
    fun stars(): Int = when {
        mistakes == 0 -> 3
        mistakes <= 2 -> 2
        else -> 1
    }

    companion object {
        const val SNAP_REACH = 0.06f
    }
}

/** Builds rooms: which places are used, and where the mess lies. */
object RoomGenerator {

    /** Every place each kind of room has, from which a level uses some. */
    private val layouts: Map<RoomKind, List<Triple<ItemType, Float, Float>>> = mapOf(
        RoomKind.BEDROOM to listOf(
            // Wall shelf.
            Triple(ItemType.BOOK, 0.16f, 0.22f), Triple(ItemType.BOOK, 0.27f, 0.22f), Triple(ItemType.CLOCK, 0.40f, 0.21f), Triple(ItemType.FRAME, 0.62f, 0.18f),
            // Bed.
            Triple(ItemType.PILLOW, 0.60f, 0.47f), Triple(ItemType.PILLOW, 0.80f, 0.47f), Triple(ItemType.TEDDY, 0.70f, 0.55f),
            // Bedside table.
            Triple(ItemType.LAMP, 0.18f, 0.44f), Triple(ItemType.MUG, 0.30f, 0.48f),
            // By the bed.
            Triple(ItemType.SHOE, 0.42f, 0.70f), Triple(ItemType.SHOE, 0.52f, 0.70f), Triple(ItemType.SOCK, 0.88f, 0.70f),
        ),
        RoomKind.KITCHEN to listOf(
            Triple(ItemType.PLATE, 0.14f, 0.20f), Triple(ItemType.PLATE, 0.26f, 0.20f), Triple(ItemType.MUG, 0.40f, 0.21f), Triple(ItemType.MUG, 0.52f, 0.21f),
            Triple(ItemType.CLOCK, 0.80f, 0.16f),
            Triple(ItemType.BOTTLE, 0.14f, 0.45f), Triple(ItemType.VASE, 0.30f, 0.45f), Triple(ItemType.PLANT, 0.46f, 0.44f), Triple(ItemType.MUG, 0.60f, 0.47f),
            Triple(ItemType.PLATE, 0.76f, 0.48f), Triple(ItemType.TOWEL, 0.88f, 0.56f), Triple(ItemType.BOTTLE, 0.88f, 0.40f),
        ),
        RoomKind.BATHROOM to listOf(
            Triple(ItemType.BOTTLE, 0.14f, 0.22f), Triple(ItemType.BOTTLE, 0.25f, 0.22f), Triple(ItemType.DUCK, 0.37f, 0.23f), Triple(ItemType.PLANT, 0.50f, 0.21f),
            Triple(ItemType.FRAME, 0.80f, 0.17f),
            Triple(ItemType.TOWEL, 0.16f, 0.45f), Triple(ItemType.TOWEL, 0.30f, 0.45f), Triple(ItemType.MUG, 0.62f, 0.44f), Triple(ItemType.BOTTLE, 0.74f, 0.44f),
            Triple(ItemType.DUCK, 0.70f, 0.60f), Triple(ItemType.DUCK, 0.84f, 0.60f), Triple(ItemType.SOCK, 0.20f, 0.70f),
        ),
        RoomKind.LIVING to listOf(
            Triple(ItemType.BOOK, 0.12f, 0.20f), Triple(ItemType.BOOK, 0.22f, 0.20f), Triple(ItemType.BOOK, 0.32f, 0.20f), Triple(ItemType.VASE, 0.46f, 0.19f),
            Triple(ItemType.FRAME, 0.72f, 0.17f), Triple(ItemType.CLOCK, 0.88f, 0.18f),
            Triple(ItemType.PILLOW, 0.56f, 0.48f), Triple(ItemType.PILLOW, 0.80f, 0.48f),
            Triple(ItemType.GAMEPAD, 0.18f, 0.48f), Triple(ItemType.MUG, 0.32f, 0.48f), Triple(ItemType.PLANT, 0.10f, 0.62f), Triple(ItemType.LAMP, 0.92f, 0.56f),
        ),
        RoomKind.PLAYROOM to listOf(
            Triple(ItemType.TEDDY, 0.14f, 0.20f), Triple(ItemType.DUCK, 0.27f, 0.21f), Triple(ItemType.GAMEPAD, 0.40f, 0.22f), Triple(ItemType.BOOK, 0.53f, 0.21f),
            Triple(ItemType.CLOCK, 0.80f, 0.16f),
            Triple(ItemType.TEDDY, 0.20f, 0.46f), Triple(ItemType.BOOK, 0.34f, 0.47f), Triple(ItemType.BOOK, 0.44f, 0.47f), Triple(ItemType.PILLOW, 0.70f, 0.50f),
            Triple(ItemType.SOCK, 0.84f, 0.50f), Triple(ItemType.SHOE, 0.62f, 0.70f), Triple(ItemType.SHOE, 0.74f, 0.70f),
        ),
    )

    fun kind(level: Int): RoomKind = RoomKind.entries[(level - 1).mod(RoomKind.entries.size)]

    /** Items in a level: 4 at first, up to every place in the room. */
    fun itemCount(level: Int): Int = (4 + (level - 1) / 2).coerceAtMost(12)

    fun generate(level: Int, seed: Long = level * 4099L + 7): Room {
        val random = Random(seed)
        val kind = kind(level)
        val all = layouts.getValue(kind)
        val chosen = all.indices.shuffled(random).take(itemCount(level).coerceAtMost(all.size)).sorted()
        val slots = chosen.mapIndexed { i, idx ->
            val (type, x, y) = all[idx]
            Slot(i, type, x, y, SIZES[type.ordinal])
        }
        // Scatter the items across the floor, spread out so they don't pile up.
        val items = ArrayList<Item>()
        for ((i, s) in slots.withIndex()) {
            var x = 0f
            var y = 0f
            for (attempt in 0 until 60) {
                x = 0.1f + random.nextFloat() * 0.8f
                y = FLOOR_TOP + random.nextFloat() * (FLOOR_BOTTOM - FLOOR_TOP)
                if (items.none { hypot(it.x - x, it.y - y) < 0.15f }) break
            }
            items += Item(i, s.type, x, y, s.size, tilt = (random.nextFloat() - 0.5f) * 50f)
        }
        return Room(kind, slots, items.shuffled(random).mapIndexed { i, it -> Item(i, it.type, it.x, it.y, it.size, it.tilt) })
    }

    const val FLOOR_TOP = 0.78f
    const val FLOOR_BOTTOM = 0.95f

    /** How big each kind of item is, as a fraction of the room's width. */
    private val SIZES = floatArrayOf(
        0.10f, 0.11f, 0.14f, 0.12f, 0.19f, 0.15f, 0.12f, 0.12f, 0.14f, 0.10f, 0.14f, 0.11f, 0.14f, 0.11f, 0.14f, 0.10f,
    )
}
