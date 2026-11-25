package com.hamxanadeem.clipcraft.server

import com.hamxanadeem.clipcraft.core.AdvisorException
import com.hamxanadeem.clipcraft.core.ClipPlan
import com.hamxanadeem.clipcraft.core.ClipSource
import com.hamxanadeem.clipcraft.core.Clips
import com.hamxanadeem.clipcraft.core.Script
import com.hamxanadeem.clipcraft.core.Transcript
import com.hamxanadeem.clipcraft.core.Wire
import com.hamxanadeem.clipcraft.core.Word
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDate

class ServerTest {
    private class Fake(val fail: Boolean = false) : ClipSource {
        var seenNotes = ""
        override fun suggest(t: Transcript, count: Int, notes: String, loudness: FloatArray): List<ClipPlan> {
            if (fail) throw AdvisorException("busy")
            seenNotes = notes
            return listOf(ClipPlan(1.0, 20.0, "Clip of ${t.words.size} words", "d", listOf("#x"), 80, "r", "h"))
        }

        override fun transliterate(words: List<String>, script: Script): List<String> = words.map { it.uppercase() }
    }

    private val transcript = Transcript((0 until 40).map { Word("w$it", it * 0.5, it * 0.5 + 0.4) })
    private val clipsBody = Wire.clipsRequest(transcript, floatArrayOf(0.1f), 3, "tech")

    @Test
    fun `finds clips through the shared core`() {
        val fake = Fake()
        val r = ClipServer(fake).handle("POST", "/v1/clips", emptyMap(), clipsBody, "1.2.3.4")
        assertEquals(200, r.status)
        assertEquals("Clip of 40 words", Clips.fromJson(r.body).single().title)
        assertEquals("tech", fake.seenNotes)
    }

    @Test
    fun `converts scripts`() {
        val r = ClipServer(Fake()).handle("POST", "/v1/script", emptyMap(), Wire.scriptRequest(listOf("kya", "hai"), Script.URDU), "ip")
        assertEquals(200, r.status)
        assertTrue(r.body.contains("\"KYA\""))
    }

    @Test
    fun `checks the token, the method and the path`() {
        val s = ClipServer(Fake(), appToken = "secret")
        assertEquals(401, s.handle("POST", "/v1/clips", emptyMap(), clipsBody, "ip").status)
        assertEquals(200, s.handle("POST", "/v1/clips", mapOf("x-clipcraft-token" to "secret"), clipsBody, "ip").status)
        assertEquals(405, s.handle("GET", "/v1/clips", emptyMap(), "", "ip").status)
        assertEquals(404, s.handle("POST", "/v1/messages", mapOf("x-clipcraft-token" to "secret"), "{}", "ip").status)
        assertEquals(200, s.handle("GET", "/health", emptyMap(), "", "ip").status)
    }

    @Test
    fun `limits each device per day and resets tomorrow`() {
        var day = LocalDate.of(2026, 1, 1)
        val s = ClipServer(Fake(), dailyLimit = 2, today = { day })
        val h = mapOf("x-device" to "phone-1")
        repeat(2) { assertEquals(200, s.handle("POST", "/v1/clips", h, clipsBody, "ip").status) }
        assertEquals(429, s.handle("POST", "/v1/clips", h, clipsBody, "ip").status)
        assertEquals(200, s.handle("POST", "/v1/clips", mapOf("x-device" to "phone-2"), clipsBody, "ip").status)
        day = day.plusDays(1)
        assertEquals(200, s.handle("POST", "/v1/clips", h, clipsBody, "ip").status)
    }

    @Test
    fun `bad input and ai errors are reported, not thrown`() {
        assertEquals(400, ClipServer(Fake()).handle("POST", "/v1/clips", emptyMap(), "{oops", "ip").status)
        assertEquals(502, ClipServer(Fake(fail = true)).handle("POST", "/v1/clips", emptyMap(), clipsBody, "ip").status)
    }
}
