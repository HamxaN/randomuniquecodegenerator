package com.hamxanadeem.clipcraft.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import kotlin.math.abs

class ProjectTest {
    @Test
    fun `projects round trip with edits and uploads`() {
        val plan = ClipPlan(10.0, 40.5, "Title \"quoted\"", "Desc\nline", listOf("#a", "#b"), 88, "why", "hook")
        val p = Project("p1", "My video", "content://x/1", 123L, "hi", Project.READY, "done", true, listOf(
            ClipState(plan),
            ClipState(plan.copy(start = 50.0, end = 80.0), listOf(Word("کیا", 50.0, 50.4), Word("ہے", 50.4, 50.9)),
                "/data/clip.mp4", "abc123", "processed", "2026-12-01T18:00:00Z"),
        ))
        val back = ProjectCodec.decode(ProjectCodec.encode(p))
        assertEquals(p, back)
        assertNull(ProjectCodec.decode("not json"))
    }
}

class ReframeTest {
    @Test
    fun `crop fraction for landscape and portrait`() {
        assertEquals(0.31640625, Reframe.cropFraction(1920, 1080), 1e-6)
        assertEquals(1.0, Reframe.cropFraction(1080, 1920))
    }

    @Test
    fun `pan follows the face, stays inside the frame, and ignores jitter`() {
        val crop = Reframe.cropFraction(1920, 1080)
        val limit = 1 - crop
        // Face on the left for 4 s, a gap, then far right.
        val samples = (0..3).map { FaceSample(it.toDouble(), 0.3 + (if (it % 2 == 0) 0.005 else -0.005)) } +
            FaceSample(4.0, null) + (5..8).map { FaceSample(it.toDouble(), 0.98) }
        val path = Reframe.path(samples, crop)
        assertTrue(path.at(1.0) > 0.0, "a face on the left means shifting the picture right")
        assertTrue(abs(path.at(1.0) - path.at(2.0)) < 1e-9, "tiny movements don't move the shot")
        assertEquals(-limit, path.at(8.0), 1e-9)
        for (t in 0..80) assertTrue(abs(path.at(t / 10.0)) <= limit + 1e-9)
    }

    @Test
    fun `no faces or a tall video means no pan`() {
        assertTrue(Reframe.path(listOf(FaceSample(0.0, null)), 0.3).still)
        assertTrue(Reframe.path(listOf(FaceSample(0.0, 0.9)), 1.0).still)
        assertEquals(0.0, Reframe.path(emptyList(), 0.3).at(5.0))
    }
}

class EditTest {
    private val words = listOf(Word("helo", 1.0, 1.4), Word("wrld", 1.5, 2.0))

    @Test
    fun `same word count keeps timings`() {
        val r = Captions.retime(words, "hello world")
        assertEquals(listOf("hello", "world"), r.map { it.text })
        assertEquals(1.5, r[1].start)
    }

    @Test
    fun `different word count shares the time`() {
        val r = Captions.retime(words, "hello big world")
        assertEquals(3, r.size)
        assertEquals(1.0, r.first().start)
        assertEquals(2.0, r.last().end, 1e-9)
        assertTrue(Captions.retime(words, "   ").isEmpty())
    }

    @Test
    fun `replace swaps words in place`() {
        val all = listOf(Word("a", 0.0, 0.5)) + words + Word("z", 2.5, 3.0)
        val out = Captions.replace(all, words, Captions.retime(words, "x y q"))
        assertEquals(listOf("a", "x", "y", "q", "z"), out.map { it.text })
    }

    @Test
    fun `captions build from a word list`() {
        val caps = Captions.build(words, 0.5, 3.0)
        assertEquals("helo wrld", caps.single().text)
        assertEquals(0.5, caps.single().start, 1e-9)
    }

    @Test
    fun `trim nudges stay in bounds`() {
        val p = ClipPlan(10.0, 30.0, "t", "d", emptyList(), 50, "r")
        assertEquals(9.0, Clips.nudge(p, -1.0, 0.0, 100.0).start)
        assertEquals(0.0, Clips.nudge(p, -50.0, 0.0, 100.0).start)
        assertEquals(15.0, Clips.nudge(p.copy(end = 16.0), 0.0, -5.0, 100.0).end - 0.0, 1e-9)
        assertEquals(100.0, Clips.nudge(p, 0.0, 500.0, 100.0).end)
        val long = Clips.nudge(p.copy(start = 0.0, end = 170.0), 0.0, 30.0, 400.0)
        assertTrue(long.end - long.start <= 180.0)
    }
}

class CuesTest {
    @Test
    fun `prompt marks loud lines, pauses and sound without speech`() {
        val words = listOf(
            Word("hello", 0.5, 1.0), Word("there", 1.0, 1.5), Word("my", 1.5, 2.0), Word("friends.", 2.0, 2.5),
            Word("THIS", 5.0, 5.4), Word("IS", 5.4, 5.8), Word("HUGE!", 5.8, 6.3),
            Word("ok", 10.0, 10.4),
        )
        val t = Transcript(words)
        val loud = FloatArray(24) { i ->
            val s = i * 0.5
            when {
                s in 0.5..2.5 -> 0.2f
                s in 5.0..6.3 -> 0.5f
                s in 6.5..9.5 -> 0.3f // laughter after the big line
                s in 10.0..10.4 -> 0.2f
                else -> 0.005f
            }
        }
        val p = t.forPrompt(loudness = loud)
        assertTrue(p.contains("HUGE! (said loudly)"), p)
        assertTrue(p.contains("sound without speech"), p)
        assertTrue(p.contains("[pause"), p)
        assertFalse(t.forPrompt().contains("said loudly"))
        assertTrue(ClipAdvisor.prompt(t, 3, "", loud).contains("Sound cues are marked"))
    }
}

class ScriptScheduleWireTest {
    @Test
    fun `script replies must match word for word`() {
        assertEquals(listOf("kya", "hai"), Scripts.parse("""{"words":["kya","hai"]}""", 2))
        assertNull(Scripts.parse("""{"words":["kya"]}""", 2))
        assertNull(Scripts.parse("""{"words":["kya",""]}""", 2))
        val w = Scripts.apply(listOf(Word("क्या", 1.0, 1.3)), listOf("kya"))
        assertEquals(Word("kya", 1.0, 1.3), w.single())
        assertEquals(Script.URDU, Script.of("URDU"))
        assertEquals(Script.AS_SPOKEN, Script.of("nope"))
        assertTrue(ClipAdvisor.scriptSystem(Script.ROMAN_URDU).contains("Roman Urdu"))
    }

    @Test
    fun `schedule spaces posts in utc`() {
        val t = Schedule.times(1_764_612_000_000L, 24, 3)
        assertEquals(listOf("2025-12-01T18:00:00Z", "2025-12-02T18:00:00Z", "2025-12-03T18:00:00Z"), t)
    }

    @Test
    fun `scheduled uploads are private with publishAt`() {
        val p = ClipPlan(0.0, 30.0, "T", "D", emptyList(), 70, "r")
        val status = Json.obj(Json.obj(Json.parse(YouTube.metadata(p, "public", publishAt = "2025-12-01T18:00:00Z")))["status"])
        assertEquals("private", status["privacyStatus"])
        assertEquals("2025-12-01T18:00:00Z", status["publishAt"])
        val now = Json.obj(Json.obj(Json.parse(YouTube.metadata(p, "public")))["status"])
        assertEquals("public", now["privacyStatus"])
        assertFalse(now.containsKey("publishAt"))
    }

    @Test
    fun `server wire format round trips`() {
        val t = Talk.transcript()
        val req = Wire.parseClipsRequest(Wire.clipsRequest(t, floatArrayOf(0.1f, 0.2f), 4, "notes"))
        assertEquals(t.words.size, req.transcript.words.size)
        assertEquals(4, req.count)
        assertEquals(2, req.loudness.size)
        val plans = listOf(ClipPlan(1.0, 20.0, "A", "B", listOf("#x"), 90, "R", "H"))
        assertEquals(plans, Clips.fromJson(Wire.clipsResponse(plans)))
        val (words, script) = Wire.parseScriptRequest(Wire.scriptRequest(listOf("a", "b"), Script.URDU))
        assertEquals(listOf("a", "b"), words)
        assertEquals(Script.URDU, script)
        assertNotNull(Json.obj(Json.parse(Wire.error("x \"y\"")))["error"])
    }
}
