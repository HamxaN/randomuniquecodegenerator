package com.hamxanadeem.clipcraft.core

/** One on-screen caption: a few words shown together, with the word being spoken highlighted. */
data class Caption(val words: List<Word>, val start: Double, val end: Double) {
    val text: String get() = words.joinToString(" ") { it.text }

    /** The index of the word being said at [t] (seconds), or -1. */
    fun active(t: Double): Int = words.indexOfLast { it.start <= t }
}

object Captions {
    /** Groups the clip's words into short captions (up to [maxWords] words / [maxChars] letters). */
    fun build(t: Transcript, start: Double, end: Double, maxWords: Int = 3, maxChars: Int = 18): List<Caption> {
        val words = t.between(start, end).map { it.copy(start = it.start - start, end = it.end - start) }
        val out = mutableListOf<Caption>()
        var cur = mutableListOf<Word>()
        fun flush() {
            if (cur.isNotEmpty()) {
                out += Caption(cur, cur.first().start, cur.last().end)
                cur = mutableListOf()
            }
        }
        for (w in words) {
            val chars = cur.sumOf { it.text.length + 1 } + w.text.length
            val gap = if (cur.isEmpty()) 0.0 else w.start - cur.last().end
            if (cur.size >= maxWords || chars > maxChars || gap > 0.6) flush()
            cur += w
            if (w.text.lastOrNull() in setOf('.', '!', '?', ',')) flush()
        }
        flush()
        // Each caption stays up until the next one starts (or a moment after the last word).
        return out.mapIndexed { i, c ->
            val next = out.getOrNull(i + 1)?.start ?: (c.end + 0.6)
            c.copy(start = c.start.coerceAtLeast(0.0), end = minOf(next, c.end + 1.0))
        }
    }

    /** The caption on screen at [t] seconds into the clip. */
    fun at(captions: List<Caption>, t: Double): Caption? = captions.lastOrNull { it.start <= t && t < it.end }
}
