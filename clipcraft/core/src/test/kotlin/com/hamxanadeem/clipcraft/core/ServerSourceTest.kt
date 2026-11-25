package com.hamxanadeem.clipcraft.core

import com.sun.net.httpserver.HttpServer
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.net.InetSocketAddress

class ServerSourceTest {
    private fun serve(status: Int, reply: (String, String) -> String, check: (Map<String, String>) -> Unit = {}): HttpServer {
        val s = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        s.createContext("/") { ex ->
            check(ex.requestHeaders.entries.associate { it.key.lowercase() to it.value.first() })
            val body = ex.requestBody.readBytes().toString(Charsets.UTF_8)
            val out = reply(ex.requestURI.path, body).toByteArray()
            ex.sendResponseHeaders(status, out.size.toLong())
            ex.responseBody.use { it.write(out) }
        }
        s.start()
        return s
    }

    private val t = Transcript((0 until 120).map { Word("w$it", it * 0.5, it * 0.5 + 0.4) })

    @Test
    fun clipsRoundTrip() {
        var seen = ""
        val s = serve(200, { path, body ->
            seen = path
            val r = Wire.parseClipsRequest(body)
            assertEquals(3, r.count)
            assertEquals(2, r.loudness.size)
            Wire.clipsResponse(listOf(ClipPlan(5.0, 30.0, "T", "D", listOf("#a"), 90, "R", "H")))
        }, { h -> assertEquals("tok", h["x-clipcraft-token"]) })
        try {
            val src = ServerClipSource("http://127.0.0.1:${s.address.port}/", "tok", "dev")
            val plans = src.suggest(t, 3, "n", floatArrayOf(0.1f, 0.2f))
            assertEquals("/v1/clips", seen)
            assertEquals(1, plans.size)
            assertEquals("T", plans[0].title)
        } finally {
            s.stop(0)
        }
    }

    @Test
    fun scriptAndErrors() {
        val s = serve(200, { _, body ->
            val (words, _) = Wire.parseScriptRequest(body)
            "{\"words\":${Scripts.request(words.map { it.uppercase() })}}"
        })
        try {
            val src = ServerClipSource("http://127.0.0.1:${s.address.port}")
            assertEquals(listOf("A", "B"), src.transliterate(listOf("a", "b"), Script.ROMAN_URDU))
            assertEquals(listOf("a"), src.transliterate(listOf("a"), Script.AS_SPOKEN))
        } finally {
            s.stop(0)
        }
        val bad = serve(429, { _, _ -> Wire.error("Daily limit reached.") })
        try {
            val e = assertThrows<AdvisorException> { ServerClipSource("http://127.0.0.1:${bad.address.port}").suggest(t, 2, "", FloatArray(0)) }
            assertTrue(e.message!!.contains("Daily limit"))
        } finally {
            bad.stop(0)
        }
        assertThrows<AdvisorException> { ServerClipSource("ftp://x").suggest(t, 2, "", FloatArray(0)) }
    }
}
