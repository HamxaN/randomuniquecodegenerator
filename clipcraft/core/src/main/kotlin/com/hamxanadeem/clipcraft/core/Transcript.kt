package com.hamxanadeem.clipcraft.core

import java.util.Locale

/** One recognised word with its time in the video, in seconds. */
data class Word(val text: String, val start: Double, val end: Double, val conf: Double = 1.0)

/** A sentence-like run of words. */
data class Line(val words: List<Word>) {
    val start: Double get() = words.first().start
    val end: Double get() = words.last().end
    val text: String get() = words.joinToString(" ") { it.text }
}

class Transcript(words: List<Word>) {
    val words: List<Word> = words.filter { it.text.isNotBlank() }.sortedBy { it.start }

    val duration: Double get() = words.lastOrNull()?.end ?: 0.0

    /**
     * Splits into lines at sentence punctuation, long pauses, or about 18 words, so
     * the model (and the clip snapper) can work in whole thoughts.
     */
    fun lines(pause: Double = 0.7, maxWords: Int = 18): List<Line> {
        val out = mutableListOf<Line>()
        var cur = mutableListOf<Word>()
        for ((i, w) in words.withIndex()) {
            if (cur.isNotEmpty()) {
                val gap = w.start - cur.last().end
                val endPunct = cur.last().text.lastOrNull() in setOf('.', '!', '?', '۔', '।')
                if (gap > pause || endPunct || cur.size >= maxWords) {
                    out += Line(cur)
                    cur = mutableListOf()
                }
            }
            cur += w
            if (i == words.size - 1) out += Line(cur)
        }
        return out
    }

    fun between(start: Double, end: Double): List<Word> = words.filter { it.end > start && it.start < end }

    /**
     * The transcript as timestamped lines for the model: "[12.4-18.9] text". With
     * [loudness], sound cues are added: loud lines, pauses, and sound without speech
     * (music, laughter, reactions), which often mark the moments that go viral.
     */
    fun forPrompt(maxChars: Int = 400_000, loudness: FloatArray = FloatArray(0)): String {
        val sb = StringBuilder()
        val ls = lines()
        val cues = if (loudness.isEmpty()) null else SoundCues(this, loudness)
        for ((i, l) in ls.withIndex()) {
            if (cues != null && i > 0) cues.gap(ls[i - 1].end, l.start)?.let { sb.append(it).append('\n') }
            val loud = if (cues != null && cues.loud(l)) " (said loudly)" else ""
            val row = "[%.1f-%.1f] %s%s\n".format(Locale.ROOT, l.start, l.end, l.text, loud)
            if (sb.length + row.length > maxChars) break
            sb.append(row)
        }
        return sb.toString()
    }

    companion object {
        /** Reads the words out of Vosk recognizer results (each a JSON object with a "result" array). */
        fun fromVosk(results: List<String>): Transcript {
            val words = mutableListOf<Word>()
            for (r in results) {
                val o = runCatching { Json.obj(Json.parse(r)) }.getOrNull() ?: continue
                for (w in Json.arr(o["result"])) {
                    val m = Json.obj(w)
                    val t = Json.str(m["word"]).trim()
                    if (t.isEmpty()) continue
                    words += Word(t, Json.num(m["start"]), Json.num(m["end"]), Json.num(m["conf"], 1.0))
                }
            }
            return Transcript(words)
        }

        fun format(seconds: Double): String {
            val s = seconds.coerceAtLeast(0.0)
            val m = (s / 60).toInt()
            return "%d:%04.1f".format(Locale.ROOT, m, s - m * 60)
        }
    }
}
