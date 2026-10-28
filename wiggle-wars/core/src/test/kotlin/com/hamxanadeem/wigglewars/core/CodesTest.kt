package com.hamxanadeem.wigglewars.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.random.Random

class CodesTest {

    @Test
    fun `codes use only easy letters and have the right length`() {
        val random = Random(1)
        repeat(500) {
            val room = Codes.room(random)
            val friend = Codes.friend(random)
            assertEquals(Codes.ROOM_LENGTH, room.length)
            assertEquals(Codes.FRIEND_LENGTH, friend.length)
            assertTrue((room + friend).none { it in "ILO0123456789" })
        }
    }

    @Test
    fun `typed codes are cleaned up`() {
        assertEquals("ABCDEF", Codes.normalize("abc-def", 6))
        assertEquals("ABCDEF", Codes.normalize("  ab cd ef ", 6))
        assertEquals("QJSBA", Codes.normalize("0158a", 5))
        assertNull(Codes.normalize("ABC", 6))
        assertNull(Codes.normalize("ABCDE!", 6))
        val code = Codes.friend(Random(3))
        assertEquals(code, Codes.normalize(Codes.pretty(code), 6))
        assertEquals("ABC-DEF", Codes.pretty("ABCDEF"))
    }
}
