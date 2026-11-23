package com.hamxanadeem.clipcraft.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** A fake 3-minute talk: sentences of 8-12 words at ~2.5 words a second with pauses between. */
object Talk {
    private val sentences = listOf(
        "Welcome back to the channel everyone, today we have a big one.",
        "Nobody tells you the biggest mistake people make with money.",
        "It is not spending too much, it is never tracking anything at all.",
        "I lost ten thousand dollars before I figured this out.",
        "So here is the secret that changed everything for me.",
        "Write down every single thing you buy for thirty days.",
        "Sounds boring right? But the results are honestly insane.",
        "My friend tried it and saved five hundred in the first month.",
        "Now let me show you how I actually do it every day.",
        "First open any notes app on your phone, nothing fancy.",
        "Then after every purchase, type the amount and one word.",
        "At the end of the week, add it up and look for surprises.",
        "Why does this work? Because you cannot fix what you cannot see.",
        "That is it for today, thanks for watching and see you soon.",
    )

    fun transcript(): Transcript {
        val words = mutableListOf<Word>()
        var t = 1.0
        repeat(2) {
            for (s in sentences) {
                for (w in s.split(" ")) {
                    words += Word(w, t, t + 0.32, 0.95)
                    t += 0.4
                }
                t += 1.0
            }
        }
        return Transcript(words)
    }
}

class JsonTest {
    @Test
    fun `parses nested json`() {
        val v = Json.obj(Json.parse("""{"a": [1, 2.5, -3e2], "b": {"c": "x\"yé\n"}, "d": true, "e": null}"""))
        assertEquals(listOf(1.0, 2.5, -300.0), Json.arr(v["a"]))
        assertEquals("x\"yé\n", Json.obj(v["b"])["c"])
        assertEquals(true, v["d"])
        assertTrue(v.containsKey("e") && v["e"] == null)
        assertThrows(IllegalArgumentException::class.java) { Json.parse("{\"a\": 1} x") }
        assertEquals("\"a\\\"b\\n\"", Json.quote("a\"b\n"))
    }
}

class TranscriptTest {
    @Test
    fun `reads vosk results`() {
        val t = Transcript.fromVosk(listOf(
            """{"result":[{"conf":1.0,"end":1.11,"start":0.84,"word":"hello"},{"conf":0.9,"end":1.5,"start":1.2,"word":"world"}],"text":"hello world"}""",
            """{"text":""}""",
            "not json",
        ))
        assertEquals(2, t.words.size)
        assertEquals("world", t.words[1].text)
        assertEquals(1.5, t.duration)
    }

    @Test
    fun `splits into sentence lines`() {
        val lines = Talk.transcript().lines()
        assertEquals(32, lines.size) // 14 sentences x 2, two of them split at a "?"
        assertTrue(lines[1].text.startsWith("Nobody tells you"))
        val p = Talk.transcript().forPrompt()
        assertTrue(p.startsWith("[1.0-"))
        assertTrue(p.lines().size >= 32)
    }
}

class ClipsTest {
    private val t = Talk.transcript()

    @Test
    fun `tidy snaps to sentences and keeps lengths sane`() {
        val raw = listOf(
            ClipPlan(9.3, 40.0, "  The biggest money mistake  ", "d", listOf("money", "#finance", "money tips!"), 92, "r"),
            ClipPlan(10.0, 30.0, "Overlapping worse one", "d", emptyList(), 60, "r"),
            ClipPlan(100.0, 105.0, "Too short", "d", emptyList(), 70, "r"),
            ClipPlan(50.0, 500.0, "Too long", "d", emptyList(), 50, "r"),
            ClipPlan(30.0, 20.0, "Backwards", "d", emptyList(), 99, "r"),
        )
        val out = Clips.tidy(raw, t)
        assertEquals("The biggest money mistake", out.first().title)
        assertEquals(listOf("#money", "#finance", "#moneytips"), out.first().hashtags)
        assertFalse(out.any { it.title == "Overlapping worse one" })
        assertFalse(out.any { it.title == "Backwards" })
        val lineStarts = t.lines().map { it.start }
        for (c in out) {
            assertTrue(c.length >= Clips.MIN - 0.01 && c.length <= Clips.MAX + 0.6, "${c.title} ${c.length}")
            assertTrue(lineStarts.any { kotlin.math.abs(it - 0.15 - c.start) < 0.01 || c.start == 0.0 }, "${c.title} starts mid-sentence at ${c.start}")
        }
        // Sorted best first.
        assertEquals(out.sortedByDescending { it.score }, out)
    }

    @Test
    fun `reads the model's json reply`() {
        val reply = """
            {"clips":[
              {"start":9.3,"end":40.0,"title":"Nobody tells you this","hook":"The #1 money mistake","description":"Why tracking beats budgeting.",
               "hashtags":["money","personalfinance"],"score":91,"reason":"Bold claim then a payoff."},
              {"start":-1,"end":4,"title":"broken","hook":"","description":"","hashtags":[],"score":5,"reason":""}
            ]}
        """.trimIndent()
        val plans = Clips.fromJson(reply)
        assertEquals(1, plans.size)
        assertEquals("The #1 money mistake", plans[0].hook)
        assertEquals(91, plans[0].score)
        assertEquals(1, Clips.fromJson("```json\n$reply\n```").size)
    }

    @Test
    fun `offline picker finds the strong section`() {
        val picks = Heuristic.pick(t, 3)
        assertTrue(picks.isNotEmpty())
        assertTrue(picks.all { it.length in Clips.MIN..(Clips.MAX + 1) })
        // No overlaps.
        for (a in picks) for (b in picks) if (a !== b) assertTrue(minOf(a.end, b.end) - maxOf(a.start, b.start) < 0.3 * minOf(a.length, b.length))
    }
}

class CaptionsTest {
    private val t = Talk.transcript()

    @Test
    fun `captions are short, timed from the clip start, and follow the speech`() {
        val caps = Captions.build(t, 10.0, 30.0)
        assertTrue(caps.isNotEmpty())
        assertTrue(caps.all { it.words.size <= 3 && it.text.length <= 22 })
        assertTrue(caps.first().start >= 0.0 && caps.first().start < 2.0)
        for (i in 0 until caps.size - 1) assertTrue(caps[i].end <= caps[i + 1].start + 1e-9)
        val c = Captions.at(caps, caps[2].start + 0.01)
        assertNotNull(c)
        assertEquals(0, c!!.active(caps[2].start + 0.01))
        assertNull(Captions.at(caps, -1.0))
    }
}

class YouTubeTest {
    @Test
    fun `metadata is valid json with shorts tags`() {
        val p = ClipPlan(0.0, 30.0, "A \"quoted\" title", "Line one", listOf("#money", "#tips"), 80, "r")
        val json = Json.obj(Json.parse(YouTube.metadata(p, "unlisted")))
        val snippet = Json.obj(json["snippet"])
        assertEquals("A \"quoted\" title #shorts", snippet["title"])
        assertTrue(Json.str(snippet["description"]).endsWith("#money #tips #shorts"))
        assertEquals(listOf("money", "tips", "shorts"), Json.arr(snippet["tags"]))
        assertEquals("unlisted", Json.obj(json["status"])["privacyStatus"])
        val long = p.copy(title = "x".repeat(99))
        assertTrue(YouTube.title(long).length <= YouTube.TITLE_MAX)
    }
}

class AdvisorTest {
    @Test
    fun `prompt carries the transcript and the schema is strict`() {
        val t = Talk.transcript()
        val prompt = ClipAdvisor.prompt(t, 4, "Finance channel for students")
        assertTrue(prompt.contains("up to 4 clips"))
        assertTrue(prompt.contains("<transcript>") && prompt.contains("Nobody tells you"))
        assertTrue(prompt.contains("Finance channel"))
        val schema = ClipAdvisor.schema()._additionalProperties()
        assertEquals("object", schema["type"]?.toString()?.trim('"'))
        assertTrue(schema["required"].toString().contains("clips"))
        assertEquals("claude-haiku-5-5", ClipAdvisor.MODEL)
    }

    @Test
    fun `too little speech is refused before any request`() {
        val e = assertThrows(AdvisorException::class.java) {
            ClipAdvisor("test-key").suggest(Transcript(listOf(Word("hi", 0.0, 0.5))))
        }
        assertTrue(e.message!!.contains("Not enough speech"))
    }
}
