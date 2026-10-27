package com.hamxanadeem.tidyroom.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RoomTest {

    @Test
    fun `every item has a place, and rooms are the same each time`() {
        for (level in 1..100) {
            val room = RoomGenerator.generate(level)
            assertEquals(room.slots.size, room.items.size)
            for (type in ItemType.entries) {
                assertEquals(room.slots.count { it.type == type }, room.items.count { it.type == type }, "level $level $type")
            }
            assertTrue(room.items.all { it.y >= RoomGenerator.FLOOR_TOP && it.y <= RoomGenerator.FLOOR_BOTTOM }, "mess is on the floor")
        }
        val a = RoomGenerator.generate(7)
        val b = RoomGenerator.generate(7)
        assertEquals(a.items.map { Triple(it.type, it.x, it.y) }, b.items.map { Triple(it.type, it.x, it.y) })
        assertTrue(RoomGenerator.generate(20).items.size > RoomGenerator.generate(1).items.size)
        assertEquals(RoomKind.entries.size, (1..5).map { RoomGenerator.kind(it) }.toSet().size, "the first five levels visit every room")
    }

    @Test
    fun `items snap into a matching place and miss the wrong one`() {
        val room = RoomGenerator.generate(3)
        val item = room.items.first()
        val wrong = room.slots.firstOrNull { it.type != item.type }
        if (wrong != null) {
            val miss = room.drop(item.id, wrong.x, wrong.y)
            assertTrue(miss is DropResult.Missed)
            assertEquals(1, room.mistakes)
            assertFalse(item.placed)
        }
        val slot = room.freeSlotsFor(item.type).first()
        val hit = room.drop(item.id, slot.x + 0.02f, slot.y - 0.02f)
        assertTrue(hit is DropResult.Placed)
        assertTrue(item.placed)
        assertEquals(slot.x, item.x)
        assertTrue(room.freeSlotsFor(item.type).none { it.id == slot.id }, "that place is taken now")
    }

    @Test
    fun `following the hints tidies every room with three stars`() {
        for (level in 1..60) {
            val room = RoomGenerator.generate(level)
            var guard = 0
            while (!room.tidy && guard++ < 50) {
                val (item, slot) = room.hint() ?: break
                room.drop(item.id, slot.x, slot.y)
            }
            assertTrue(room.tidy, "level $level")
            assertEquals(3, room.stars())
            assertNotNull(room.kind)
        }
    }
}
